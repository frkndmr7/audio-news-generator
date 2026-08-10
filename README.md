
https://d12ok8ikk5mxgz.cloudfront.net/

# 📻 Smart News

**Smart News**, is a fully automated, cloud-based radio system that summarizes your favorite RSS news sources using Amazon Bedrock (AI) and delivers them to listeners in a professional radio host tone thanks to Amazon Polly's most advanced Neural Voice engine.

---

## ✨ Key Features

* **AI-Powered Summarization:** Raw news articles are transformed into fluent, concise bulletins using **Claude 3 (Haiku)**.
* **Neural Text-to-Speech:** News is narrated in a natural, clear, human-like voice using **Polly’s Neural Engine** technology.
* **Fully Automated Architecture:** The entire infrastructure is managed as code with **Terraform (IaC)**.
* **CI/CD Pipeline:** Integrated with **GitHub Actions** and **Docker** to automatically deploy code updates to AWS.
* **Edge Delivery:** Content is delivered worldwide with minimal latency via **Amazon CloudFront CDN**.

---

## 🏗️ Architecture

The application is built entirely on serverless and managed AWS services:

* **Compute & AI:** AWS Lambda, Amazon Bedrock (Claude 3 Haiku), Amazon Polly
* **Storage & CDN:** Amazon S3, Amazon CloudFront
* **IaC & CI/CD:** Terraform, Docker, GitHub Actions

News Fetching:

<img width="1440" height="1160" alt="image" src="https://github.com/user-attachments/assets/f59f1596-d290-48d0-9ea4-53dc1d2a9711" />




## ⚙️ How It Works (Workflow)

1. **RSS Ingestion:** A Python-based worker scans configured RSS feeds for new updates.
2. **Deduplication:** **Amazon DynamoDB** checks story IDs to ensure previously processed news items are skipped (*cost & performance optimization*).
3. **AI Summarization:** **Amazon Bedrock (Claude 3 Haiku)** summarizes raw text into a professional radio host style.
4. **Speech Synthesis:** **Amazon Polly** converts the structured text into high-quality MP3 audio files using its Neural Engine.
5. **Storage & CDN:** Audio files and news metadata are stored in **Amazon S3** and distributed globaly via **Amazon CloudFront**.
6. **Orchestration:** The entire workflow runs periodically as a containerized task on **AWS ECS (Fargate)**.

---

## 🛠️ Technology Stack

| Category | Technology / Service |
| :--- | :--- |
| **Cloud Provider** | AWS (Amazon Web Services) |
| **Artificial Intelligence** | Amazon Bedrock (Claude 3 Haiku) |
| **Speech Synthesis** | Amazon Polly (Neural Engine) |
| **Infrastructure as Code** | Terraform |
| **Containerization** | Docker, Amazon ECR |
| **Compute / Orchestration** | AWS ECS (Fargate) |
| **Database** | Amazon DynamoDB |
| **CI/CD Pipeline** | GitHub Actions |

---

## 📦 Setup & Deployment

### 1. Initialize Infrastructure

Navigate to the infrastructure folder and apply the Terraform configuration:

```bash
cd infra
terraform init
terraform apply ```
```

### 2. Application Deployment

The project is integrated with GitHub Actions. Every push to the main branch builds a new Docker image and updates the task running on AWS ECS.



You can access the site from here:

https://d12ok8ikk5mxgz.cloudfront.net/
