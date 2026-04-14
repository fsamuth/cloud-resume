# Architecture

This document explains how the resume website is built and hosted on AWS, written for readers who are not familiar with cloud infrastructure.

---

## What is AWS?

AWS (Amazon Web Services) is a cloud platform that lets you rent computing resources — servers, storage, databases, networking — on demand, paying only for what you use. Instead of buying and managing physical hardware, you configure services through an API or a web console.

---

## Overview

The website is made of two parts:

1. **A static frontend** — HTML, CSS, and JavaScript files that are served directly to the browser
2. **A serverless backend** — a small API that counts how many times the page has been visited

Neither part runs on a traditional server that stays on 24/7. Instead, AWS manages the infrastructure and scales it automatically.

---

## Service by service

### S3 — File storage

**What it is:** S3 (Simple Storage Service) is AWS's object storage. Think of it as a hard drive in the cloud where you store files and access them via a URL.

**How it's used here:** The HTML, CSS, and JavaScript files that make up the website are uploaded to an S3 bucket. S3 doesn't serve them directly to visitors — it hands them off to CloudFront.

---

### CloudFront — Content delivery network

**What it is:** CloudFront is AWS's CDN (Content Delivery Network). A CDN has servers spread across the world (called "edge locations"). When a visitor requests a file, it's served from the edge location closest to them rather than from a single distant server — making the website faster for everyone.

**How it's used here:** CloudFront sits in front of S3 and serves the website files. It also:
- Forces HTTPS (redirects all HTTP traffic)
- Adds security headers to every response (more on this in the [security docs](security.md))
- Caches files at the edge so S3 is rarely hit directly
- Applies basic auth on staging to restrict access

---

### ACM — SSL/TLS certificate

**What it is:** ACM (AWS Certificate Manager) issues and renews SSL certificates for free. An SSL certificate is what enables HTTPS — the padlock in your browser's address bar.

**How it's used here:** ACM issues a certificate for the domain (`fidele.samuth.com`). CloudFront uses this certificate to serve the site over HTTPS. The certificate is validated automatically by adding a DNS record to the domain.

> Note: CloudFront requires certificates to be in the `us-east-1` AWS region (US East Virginia), regardless of where the rest of the infrastructure lives.

---

### API Gateway — HTTP endpoint

**What it is:** API Gateway is a managed service that creates HTTP endpoints. It receives incoming requests, routes them to the right destination (here, a Lambda function), and returns the response.

**How it's used here:** The visitor counter needs an API that the browser can call. API Gateway exposes a single endpoint (`/count`) that the JavaScript on the page hits when a visitor loads the site.

---

### Lambda — Serverless function

**What it is:** Lambda lets you run code without managing a server. You upload a function, and AWS runs it whenever it's triggered — charging only for the milliseconds it actually executes.

**How it's used here:** A small Python function handles the visitor counter logic:
1. It receives the request from API Gateway
2. It increments the counter in DynamoDB
3. It returns the new count to the browser

The function only runs when someone visits the page. There's no server sitting idle between visits.

---

### DynamoDB — Database

**What it is:** DynamoDB is AWS's fully managed NoSQL database. It stores data as key-value pairs and scales automatically.

**How it's used here:** A single table stores the visitor count. Each time the Lambda function runs, it atomically increments the counter (meaning concurrent visits don't cause race conditions).

Point-In-Time Recovery (PITR) is enabled, which means the table can be restored to any point in the past 35 days.

---

### SQS — Dead Letter Queue

**What it is:** SQS (Simple Queue Service) is a message queue. A Dead Letter Queue (DLQ) is a special queue that captures messages (or in this case, Lambda invocations) that failed after all retry attempts.

**How it's used here:** If the Lambda function crashes and all retries are exhausted, the failed invocation is sent to the DLQ instead of being silently dropped. A CloudWatch alarm monitors the DLQ and triggers an alert email if any messages appear there.

---

### CloudWatch — Monitoring and alerting

**What it is:** CloudWatch collects metrics (numbers over time) and logs from AWS services. You can set alarms that trigger when a metric crosses a threshold.

**How it's used here:**
- **Alarms** watch for Lambda errors, high latency, API Gateway failures, and messages piling up in the DLQ
- **Dashboard** gives a visual overview of all key metrics in one place (production only)
- **Log groups** store Lambda and API Gateway logs with a defined retention period

When an alarm triggers, it sends a notification via SNS (see below).

---

### SNS — Notification service

**What it is:** SNS (Simple Notification Service) is a pub/sub messaging service. You publish a message to a "topic" and all subscribers receive it.

**How it's used here:** CloudWatch alarms publish to an SNS topic. The topic has one subscriber: an email address. When something goes wrong, an alert email is sent automatically.

---

## How the pieces fit together

```
Visitor's browser
       │
       ▼
  CloudFront  ──── serves cached files ────►  S3 (HTML/CSS/JS)
       │
       │  /api/count
       ▼
  API Gateway
       │
       ▼
  Lambda (Python)
       │
       ├──► DynamoDB (increment counter, return new value)
       │
       └──► SQS DLQ (only on failure)

CloudWatch watches Lambda + API Gateway + DynamoDB + DLQ
       │
       └──► SNS ──► Email alert
```

---

## Infrastructure as Code

All of this infrastructure is defined in code using **OpenTofu** (an open-source fork of Terraform). Instead of clicking through the AWS console to create resources, every resource is described in `.tf` files and applied automatically.

This means:
- The infrastructure can be recreated from scratch in minutes
- Changes are reviewed like code (pull requests, diffs)
- Two identical environments (staging and production) are maintained from the same codebase
