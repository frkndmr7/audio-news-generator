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

#hadi çalış