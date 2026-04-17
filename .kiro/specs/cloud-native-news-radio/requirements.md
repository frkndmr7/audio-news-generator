# Requirements Document

## Introduction

Cloud-Native Intelligent News Radio is an automated pipeline that aggregates news from RSS feeds and Reddit, summarizes articles using large language models, converts summaries to natural-sounding speech, and delivers audio broadcasts to users. The system runs on a daily schedule using AWS serverless infrastructure, optimized for cost using Fargate Spot capacity.

## Glossary

- **Orchestrator**: The ECS Fargate task that coordinates the end-to-end pipeline execution
- **Aggregator**: The component responsible for fetching news from RSS feeds and Reddit
- **Deduplicator**: The component that checks DynamoDB to prevent reprocessing of already-seen articles
- **Summarizer**: The AWS Bedrock-powered component that condenses article content into broadcast-ready text
- **TTS_Engine**: The Amazon Polly-powered component that converts text summaries to MP3 audio
- **State_Store**: The Amazon DynamoDB table used for news item state management and deduplication
- **Audio_Store**: The Amazon S3 bucket where generated MP3 files are stored
- **Scheduler**: The Amazon EventBridge rule that triggers the daily pipeline
- **Pipeline**: The complete end-to-end workflow from news ingestion to audio delivery
- **News_Item**: A single article or post fetched from an RSS feed or Reddit
- **Broadcast**: The final compiled MP3 audio file representing a complete news edition

---

## Requirements

### Requirement 1: Scheduled Pipeline Execution

**User Story:** As a system operator, I want the news pipeline to run automatically every day at 08:00 AM, so that users receive a fresh broadcast without manual intervention.

#### Acceptance Criteria

1. THE Scheduler SHALL trigger the Orchestrator at 08:00 AM UTC daily using a cron expression
2. WHEN the Scheduler fires, THE Orchestrator SHALL launch an ECS Fargate task using Spot capacity
3. IF the Fargate Spot capacity is unavailable, THEN THE Orchestrator SHALL fall back to on-demand Fargate capacity
4. WHEN the Orchestrator task completes successfully, THE Scheduler SHALL record the last successful execution timestamp in DynamoDB
5. IF the Orchestrator task fails, THEN THE Orchestrator SHALL emit a failure event to Amazon EventBridge for downstream alerting

---

### Requirement 2: News Aggregation

**User Story:** As a system operator, I want the system to collect news from multiple RSS feeds and Reddit, so that the broadcast covers a broad range of topics and sources.

#### Acceptance Criteria

1. THE Aggregator SHALL fetch articles from a configurable list of RSS feed URLs at each pipeline execution
2. THE Aggregator SHALL fetch posts from a configurable list of Reddit subreddits using the Reddit API at each pipeline execution
3. WHEN fetching from an RSS feed, THE Aggregator SHALL extract the article title, URL, publication timestamp, and summary or body text
4. WHEN fetching from Reddit, THE Aggregator SHALL extract the post title, URL, submission timestamp, and post body or linked article content
5. IF an RSS feed or Reddit endpoint is unreachable, THEN THE Aggregator SHALL log the error, skip that source, and continue processing remaining sources
6. THE Aggregator SHALL collect a maximum of 50 News_Items per source per execution to limit downstream processing cost
7. WHEN aggregation completes, THE Aggregator SHALL pass all collected News_Items to the Deduplicator

---

### Requirement 3: Deduplication and State Management

**User Story:** As a system operator, I want the system to avoid reprocessing articles it has already seen, so that each broadcast contains only new content and API costs are minimized.

#### Acceptance Criteria

1. THE Deduplicator SHALL check each News_Item against the State_Store using the article URL as the primary key
2. WHEN a News_Item URL already exists in the State_Store, THE Deduplicator SHALL discard that News_Item
3. WHEN a News_Item URL does not exist in the State_Store, THE Deduplicator SHALL pass it to the Summarizer and write its URL and ingestion timestamp to the State_Store
4. THE State_Store SHALL retain News_Item records for 30 days using DynamoDB TTL, after which records SHALL be automatically deleted
5. THE Deduplicator SHALL complete the deduplication check for all News_Items before any summarization begins
6. IF the State_Store is unreachable, THEN THE Deduplicator SHALL halt the pipeline and emit a failure event

---

### Requirement 4: AI-Powered Summarization

**User Story:** As a listener, I want each news article to be condensed into a concise, broadcast-ready summary, so that I can consume the news efficiently in audio format.

#### Acceptance Criteria

1. THE Summarizer SHALL invoke AWS Bedrock with each deduplicated News_Item's text content to generate a summary
2. WHEN invoking Bedrock, THE Summarizer SHALL use a prompt that instructs the model to produce a summary of no more than 3 sentences suitable for radio broadcast
3. THE Summarizer SHALL process News_Items sequentially to respect Bedrock API rate limits
4. IF Bedrock returns an error or throttling response, THEN THE Summarizer SHALL retry up to 3 times with exponential backoff before skipping that News_Item
5. WHEN a summary is successfully generated, THE Summarizer SHALL append the summary text to the broadcast script
6. THE Summarizer SHALL prepend each summary with the article source name and title before appending to the broadcast script

---

### Requirement 5: Text-to-Speech Conversion

**User Story:** As a listener, I want the news summaries to be converted to natural-sounding speech, so that I can listen to the broadcast as an audio file.

#### Acceptance Criteria

1. WHEN the broadcast script is complete, THE TTS_Engine SHALL invoke Amazon Polly to synthesize the full script into an MP3 audio stream
2. THE TTS_Engine SHALL use Amazon Polly's Neural TTS engine with a configurable voice ID defaulting to "Matthew"
3. IF the broadcast script exceeds Amazon Polly's 3000-character limit per request, THEN THE TTS_Engine SHALL split the script into segments of at most 2900 characters at sentence boundaries and synthesize each segment separately
4. WHEN multiple audio segments are produced, THE TTS_Engine SHALL concatenate them into a single MP3 file in the correct order
5. IF Amazon Polly returns an error, THEN THE TTS_Engine SHALL retry up to 3 times with exponential backoff before failing the pipeline
6. WHEN synthesis is complete, THE TTS_Engine SHALL pass the final MP3 binary to the Audio_Store for upload

---

### Requirement 6: Audio Storage and Delivery

**User Story:** As a listener, I want the generated audio broadcast to be stored and accessible, so that I can retrieve and play it at any time.

#### Acceptance Criteria

1. THE Audio_Store SHALL store each Broadcast as an MP3 file in S3 with a key following the pattern `broadcasts/YYYY-MM-DD/news-radio.mp3`
2. WHEN a Broadcast is uploaded, THE Audio_Store SHALL generate a pre-signed URL valid for 24 hours
3. THE Audio_Store SHALL enable S3 server-side encryption (SSE-S3) for all stored Broadcast files
4. THE Audio_Store SHALL apply an S3 lifecycle policy to transition Broadcast files to S3 Glacier after 90 days
5. WHEN the pre-signed URL is generated, THE Orchestrator SHALL publish it to an SNS topic for downstream notification delivery
6. IF the S3 upload fails, THEN THE Orchestrator SHALL retry up to 3 times before emitting a failure event

---

### Requirement 7: IAM Security and Least Privilege

**User Story:** As a security engineer, I want all AWS service interactions to use IAM roles with least-privilege permissions, so that the blast radius of any compromise is minimized.

#### Acceptance Criteria

1. THE Orchestrator SHALL execute under a dedicated IAM task role that grants only the permissions required for its specific operations
2. THE Orchestrator's IAM role SHALL include permissions to invoke Bedrock, call Polly, read/write DynamoDB, read/write S3, and publish to SNS
3. THE Orchestrator's IAM role SHALL NOT include permissions to create or modify IAM roles, policies, or other AWS infrastructure
4. WHERE S3 bucket policies are configured, THE Audio_Store SHALL deny all public access and require requests to use the pre-signed URL mechanism
5. THE State_Store SHALL have a resource-based policy that restricts write access to the Orchestrator's IAM task role only

---

### Requirement 8: Observability and Error Handling

**User Story:** As a system operator, I want comprehensive logging and error reporting, so that I can diagnose failures and monitor pipeline health.

#### Acceptance Criteria

1. THE Orchestrator SHALL emit structured JSON logs to Amazon CloudWatch Logs for every pipeline stage transition
2. WHEN a pipeline stage fails, THE Orchestrator SHALL log the stage name, error message, and stack trace to CloudWatch Logs
3. THE Orchestrator SHALL emit a custom CloudWatch metric named `PipelineExecutionDuration` with the total runtime in seconds after each execution
4. WHEN the pipeline completes successfully, THE Orchestrator SHALL emit a CloudWatch metric named `BroadcastsGenerated` with a value of 1
5. IF the pipeline fails at any stage, THE Orchestrator SHALL emit a CloudWatch metric named `PipelineFailures` with a value of 1
6. THE Orchestrator SHALL retain CloudWatch Logs for 30 days before automatic expiration
