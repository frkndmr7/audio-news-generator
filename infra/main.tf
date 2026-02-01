terraform {
  backend "s3" {
    bucket         = "frkn-terraform-state-bucket" # Az önce oluşturduğun isim
    key            = "ses-proje/terraform.tfstate"
    region         = "eu-central-1"
    # DynamoDB lock opsiyoneldir, şimdilik bu yeterli.
  }
}

# AWS Sağlayıcı Yapılandırması
provider "aws" {
  region = "eu-central-1" # Tercih ettiğin bölge
}

# 1. Ses Dosyaları İçin S3 Bucket 
resource "aws_s3_bucket" "media_bucket" {
  bucket = "ses-proje-media-storage-unique-id" # Bu isim dünyada eşsiz olmalı
}

# 2. Web Arayüzü (UI) İçin S3 Bucket
resource "aws_s3_bucket" "ui_bucket" {
  bucket = "ses-proje-ui-hosting-unique-id"
}

# S3 Web Hosting Ayarı
resource "aws_s3_bucket_website_configuration" "ui_hosting" {
  bucket = aws_s3_bucket.ui_bucket.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_cors_configuration" "media_cors" {
  bucket = aws_s3_bucket.media_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"] # Güvenlik için ileride CloudFront URL'ni yazacağız
    max_age_seconds = 3000
  }
}

# 3. Haber Takibi İçin DynamoDB Tablosu [cite: 9, 35]
resource "aws_dynamodb_table" "news_tracker" {
  name            = "ProcessedNews"
  billing_mode   = "PAY_PER_REQUEST" # Kullandıkça öde (Maliyet dostu) 
  hash_key       = "NewsID"

  attribute {
    name = "NewsID"
    type = "S" # String (Haber linki veya ID'si)
  }

  tags = {
    Project = "SesProje"
  }
}

# CloudFront'un S3'e erişmesi için gerekli kimlik (OAC)
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Dağıtımı
resource "aws_cloudfront_distribution" "ui_distribution" {

  origin {
    domain_name              = aws_s3_bucket.media_bucket.bucket_regional_domain_name
    origin_id                = "MediaBucketOrigin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  origin {
    domain_name              = aws_s3_bucket.ui_bucket.bucket_regional_domain_name
    origin_id                = "S3-UI-Hosting"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"


  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-UI-Hosting"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "*.mp3"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "MediaBucketOrigin"

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# S3 Bucket Politikası (Sadece CloudFront erişebilsin diye)
resource "aws_s3_bucket_policy" "allow_access_from_cloudfront" {
  bucket = aws_s3_bucket.ui_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.ui_bucket.arn}/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.ui_distribution.arn
          }
        }
      }
    ]
  })
}

# MEDIA BUCKET İÇİN YENİ POLİTİKA
resource "aws_s3_bucket_policy" "media_access_from_cloudfront" {
  bucket = aws_s3_bucket.media_bucket.id # DEĞİŞEN: Burası media_bucket olmalı
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.media_bucket.arn}/*" # DEĞİŞEN: Media bucket ARN
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.ui_distribution.arn # Aynı CloudFront dağıtımı
          }
        }
      }
    ]
  })
}

# Docker imajlarımızın duracağı depo
resource "aws_ecr_repository" "app_repo" {
  name                 = "audio-news-generator"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Güvenlik için her yüklemede tarama yapar
  }
}

# Çıktı olarak ECR URL'ini alalım (GitHub Actions'da lazım olacak)
output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}

# 1. ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "news-radio-cluster"
}

# 2. IAM Role: Fargate Görevinin Kendisi İçin (S3, Polly, DynamoDB'ye erişecek)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

# Bedrock Modellerini Çağırma Yetkisi
resource "aws_iam_role_policy" "bedrock_policy" {
  name = "bedrock-access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "bedrock:InvokeModel"
        Effect   = "Allow"
        Resource = "*" # Güvenlik için belirli model ARN'leri de yazılabilir
      }
    ]
  })
}

# Yetkileri role bağlayalım (Polly, S3, DynamoDB)
resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "task_polly" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPollyFullAccess"
}

resource "aws_iam_role_policy_attachment" "task_dynamo" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Bu politika, AWS'nin ECR'dan imaj çekmesini sağlar (ZORUNLUDUR)
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 3. Task Definition (İş Tanımı)
resource "aws_ecs_task_definition" "app" {
  family                   = "news-radio-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_role.arn # Imajı çekmek için
  task_role_arn            = aws_iam_role.ecs_task_role.arn # Servisleri kullanmak için

  container_definitions = jsonencode([{
    name      = "news-worker"
    image     = "${aws_ecr_repository.app_repo.repository_url}:latest"
    essential = true
    log_configuration = {
      log_driver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/news-radio"
        "awslogs-region"        = "eu-central-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# CloudWatch Log Grubu (Hataları görmek için şart)
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name = "/ecs/news-radio"
}

# 1. Zamanlayıcı Kuralı (Her sabah 08:00 UTC)
resource "aws_cloudwatch_event_rule" "every_morning" {
  name                = "run-news-worker-daily"
  description         = "Haberleri her sabah sese cevirir"
  schedule_expression = "cron(0 8 * * ? *)" # Her sabah 08:00
}

# 2. Zamanlayıcının ECS Task'ını tetiklemesi için gereken Target
resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {
  rule      = aws_cloudwatch_event_rule.every_morning.name
  arn       = aws_ecs_cluster.main.arn
  role_arn  = aws_iam_role.ecs_event_role.arn # Tetikleme yetkisi için yeni rol

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.app.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = ["subnet-0eca94079d0b738bc"] # Default subnet ID'lerinden birini yazmalısın
      assign_public_ip = true
    }
  }
}

# 3. EventBridge'in ECS'i tetikleyebilmesi için IAM Rolü
resource "aws_iam_role" "ecs_event_role" {
  name = "ecs-event-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "events.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ecs_event_policy" {
  name = "ecs-event-policy"
  role = aws_iam_role.ecs_event_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "ecs:RunTask"
      Resource = [aws_ecs_task_definition.app.arn]
    },
    {
      Effect = "Allow"
      Action = "iam:PassRole"
      Resource = [aws_iam_role.ecs_task_role.arn]
    }]
  })
}

#hadi çalış3