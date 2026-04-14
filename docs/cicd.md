# CI/CD Pipeline

This document explains how code changes are automatically tested and deployed, written for readers who are not familiar with CI/CD or GitHub Actions.

---

## What is CI/CD?

**CI (Continuous Integration)** means every code change is automatically tested before it can be merged. This catches mistakes early, before they reach production.

**CD (Continuous Deployment)** means once a change is merged, it is automatically deployed — no manual steps required (except an optional human approval gate before production).

The tool used here is **GitHub Actions**, which runs automated workflows directly on GitHub whenever certain events happen (a push, a pull request, a schedule, etc.).

---

## The two environments

There are two independent copies of the infrastructure:

| Environment | URL | Purpose |
|---|---|---|
| **Staging** | `staging.fidele.samuth.com` | Test changes before going live |
| **Production** | `fidele.samuth.com` | The live website |

Every change goes through staging first. Production only receives the change if staging succeeds and a security scan passes.

---

## Workflow overview

```
Pull Request opened
        │
        ▼
┌───────────────────────────────────┐
│  plan.yml (PR checks)             │
│  ① Unit tests                     │
│  ② Linting (TFLint)               │
│  ③ Security scan (Checkov)        │
│  ④ Infrastructure plan (staging)  │
│  ⑤ Cost estimate (Infracost)      │
└───────────────────────────────────┘
        │
        ▼
   Merge to main
        │
        ▼
┌───────────────────────────────────┐
│  deploy.yml                       │
│  ① Build Lambda package           │
│  ② Deploy to staging              │
│  ③ ZAP security scan (staging)    │
│  ④ Deploy to production  ◄── requires manual approval
└───────────────────────────────────┘
```

---

## On every pull request — `plan.yml`

Before any change can be merged, four checks run automatically:

### ① Unit tests

The Lambda function (visitor counter) has automated tests written with **pytest**. AWS services are mocked using **moto**, so the tests run without needing a real AWS account.

If the tests fail, the pull request is blocked.

### ② Linting with TFLint

**TFLint** checks the Terraform/OpenTofu infrastructure code for common mistakes — deprecated syntax, invalid values, misconfigurations.

### ③ Security analysis with Checkov

**Checkov** scans the infrastructure code against a library of known security misconfigurations (e.g. public S3 buckets, unencrypted databases, missing access logs). Results are uploaded to the GitHub Security tab as a SARIF report.

### ④ Infrastructure plan

OpenTofu runs a `plan` against the staging environment — it connects to AWS, compares the desired state (the code) against the actual state, and produces a diff of what would change.

The diff is posted as a comment on the pull request so reviewers can see exactly what infrastructure will be created, modified, or destroyed.

### ⑤ Cost estimate with Infracost

**Infracost** reads the infrastructure plan and estimates the monthly AWS cost impact of the change. The estimate is posted as a comment on the pull request.

This is particularly useful when adding new resources — a reviewer can immediately see if a change would significantly increase the bill.

---

## On merge to main — `deploy.yml`

Once a pull request is merged, the deployment pipeline runs automatically.

### ① Build Lambda package

The Python function (`counter.py`) is packaged into a zip file and uploaded to an S3 artifacts bucket. The file is named using a SHA256 hash of its contents — if the code hasn't changed, the existing file is reused without re-uploading.

### ② Deploy to staging

The reusable deployment workflow (`_deploy-env.yml`) runs three jobs in sequence:

1. **Plan** — runs `tofu plan` to compute what needs to change
2. **Apply** — runs `tofu apply` to apply the changes (this is a no-op if nothing changed)
3. **Sync** — uploads the website files to S3, injects the API endpoint URL into the JavaScript, and invalidates the CloudFront cache so visitors immediately get the new version

### ③ ZAP security scan

**OWASP ZAP** (Zed Attack Proxy) runs a passive baseline scan against the staging URL. It checks for common web vulnerabilities — missing security headers, exposed server information, insecure cookie settings, etc.

If ZAP finds critical issues, the production deployment is blocked. If it only finds warnings, the pipeline continues. A GitHub issue is created with the full report.

### ④ Deploy to production

The same deployment workflow runs again, this time against production — but only if:
- Staging deployment succeeded
- ZAP scan did not find critical failures

Additionally, the **production GitHub environment has a required reviewer**: a human must approve the deployment before it proceeds. This is the manual gate that prevents accidental production changes.

---

## Reusable workflow — `_deploy-env.yml`

To avoid duplicating code between staging and production, both environments use the same underlying workflow, parameterised by environment name.

The workflow:
1. Runs `tofu init` to initialise OpenTofu with the remote state backend
2. Runs `tofu plan` with the environment-specific variables
3. Waits for approval (production only, enforced by the GitHub environment protection rule)
4. Runs `tofu apply` with the saved plan
5. Syncs website files to S3 with correct cache headers:
   - HTML files: `no-cache` — the browser always checks for a new version
   - CSS/JS/images: `max-age=31536000,immutable` — cached for 1 year (since filenames change when content changes)
6. Invalidates the CloudFront cache to force edge locations to fetch fresh files

---

## Scheduled workflows

Two workflows run on a schedule, independently of any deployment:

### Daily drift detection — `drift.yml`

Runs every morning at 6am UTC. It runs `tofu plan` against production — if the actual AWS infrastructure no longer matches what the code describes (e.g. someone manually changed something in the AWS console), it opens a GitHub issue with the diff.

This ensures the infrastructure is always managed through code, not manual changes.

### Weekly security scan — `security.yml`

Runs every Monday at 8am UTC. It runs the same ZAP passive scan used in the deployment pipeline, but against the live staging environment. This catches new vulnerabilities that may have been disclosed since the last deployment, even if no code has changed.

---

## Authentication with AWS

GitHub Actions needs permission to create and modify AWS resources. Instead of storing a long-lived AWS access key as a secret (which could leak and be misused indefinitely), the pipeline uses **OIDC (OpenID Connect)**.

With OIDC, GitHub Actions presents a short-lived token to AWS. AWS verifies that the token genuinely comes from this specific repository, and issues temporary credentials that expire after the workflow run finishes.

This means:
- No permanent credentials to rotate or accidentally expose
- Access is automatically revoked when the workflow ends
- The IAM role is scoped to only the permissions needed — it cannot delete the S3 bucket or the CloudFront distribution
