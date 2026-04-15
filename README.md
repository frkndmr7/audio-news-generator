
https://dy39xpxx4bxbc.cloudfront.net/

Smart AI News Radio

This project is a fully automated, cloud-based news radio system that summarizes content from your favorite news sources (RSS) using Amazon Bedrock (AI) and delivers it in a professional radio host voice using Amazon Polly (Neural Engine). 🚀

Key Features

AI-Powered Summarization:
Raw news articles are transformed into fluent, concise bulletins using Claude 3 (Haiku).

Neural Text-to-Speech:
News is narrated in a natural, clear, human-like voice using Polly’s most advanced Neural Engine technology.

Fully Automated Architecture:
The entire infrastructure is managed with Terraform (Infrastructure as Code).

CI/CD Pipeline:
With GitHub Actions and Docker integration, the application is automatically deployed on AWS whenever the code is updated.

Edge Delivery:
Content is delivered worldwide with low latency via the CloudFront CDN.


🏗️ Architecture

The application is built entirely on serverless and managed services:

News Fetching:

<img width="1440" height="1228" alt="image" src="https://github.com/user-attachments/assets/91255e56-ed83-4109-abee-65eec6b624fc" />



A Python-based worker scans RSS feeds.

Control Mechanism:
DynamoDB ensures previously processed news items are skipped (cost and performance optimization).

AI Processing:
Amazon Bedrock summarizes raw text in a radio host tone.

Text-to-Speech:
Amazon Polly converts the summarized text into high-quality MP3 audio files.

Storage & Delivery:
Audio files and news lists are stored in S3 and served via CloudFront.

Orchestration:
The entire workflow runs periodically on AWS ECS (Fargate).




🛠️ Technology Stack

Cloud Provider:	AWS (Amazon Web Services)
Artificial Intelligence:	Amazon Bedrock (Claude 3 Haiku)
Speech Synthesis:	Amazon Polly (Neural Engine)
Infrastructure (IaC):	Terraform
Containerization:	Docker, Amazon ECR
Compute:	AWS ECS (Fargate)
Database:	Amazon DynamoDB
CI/CD:	GitHub Actions



📦 Setup & Deployment
1. Initialize Infrastructure
cd infra
terraform init
terraform apply

2. Application Deployment

The project is integrated with GitHub Actions. Every push to the main branch builds a new Docker image and updates the task running on AWS ECS.


Future Plans (Roadmap)

 Categorization of multiple RSS sources

 An admin panel allowing users to add their own RSS links




You can access the site from here:

https://dy39xpxx4bxbc.cloudfront.net/
