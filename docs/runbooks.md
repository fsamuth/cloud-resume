# Runbooks

Procedures for handling operational problems. Each runbook describes the symptoms, the cause, and the steps to resolve it.

**Prerequisites:** AWS CLI configured, OpenTofu installed, access to the GitHub repository.

---

## Table of contents

- [Roll back a website deployment](#roll-back-a-website-deployment)
- [Roll back infrastructure changes](#roll-back-infrastructure-changes)
- [Force-unlock a stuck Terraform state](#force-unlock-a-stuck-terraform-state)
- [Manually invalidate the CloudFront cache](#manually-invalidate-the-cloudfront-cache)
- [Investigate Lambda errors](#investigate-lambda-errors)
- [Drain the Dead Letter Queue](#drain-the-dead-letter-queue)
- [Respond to a drift detection alert](#respond-to-a-drift-detection-alert)
- [Re-validate the ACM certificate](#re-validate-the-acm-certificate)
- [Restore DynamoDB table from Point-In-Time Recovery](#restore-dynamodb-table-from-point-in-time-recovery)

---

## Roll back a website deployment

**Symptoms:** The live site is broken after a deployment (blank page, layout broken, JavaScript error in the browser console).

**Cause:** A bad website file (HTML/CSS/JS) was synced to S3.

**Resolution:** Revert the commit that introduced the bad change and let the pipeline redeploy.

```bash
# Find the last known good commit
git log --oneline

# Revert the bad commit (creates a new commit — does not rewrite history)
git revert <bad-commit-hash>
git push origin main
```

The pipeline will trigger automatically and redeploy the previous version.

**If you need an immediate fix without waiting for CI/CD:**

```bash
# Check out the last good version of the files locally
git checkout <last-good-commit-hash> -- website/public/

# Sync manually (replace BUCKET_NAME with the actual bucket)
aws s3 sync website/public/ s3://BUCKET_NAME/ --delete \
  --exclude "*.html" --cache-control "max-age=31536000,immutable"
aws s3 sync website/public/ s3://BUCKET_NAME/ --delete \
  --exclude "*" --include "*.html" --cache-control "no-cache"

# Invalidate CloudFront to push the change to the edge
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"
```

> Bucket name and distribution ID are available as Terraform outputs:
> ```bash
> cd terraform/envs/production && tofu output
> ```

---

## Roll back infrastructure changes

**Symptoms:** A Terraform apply introduced a breaking infrastructure change (e.g. wrong Lambda configuration, broken API Gateway route).

**Cause:** A bad infrastructure change was applied.

**Resolution:**

**Option 1 — Revert via git (preferred)**

Revert the Terraform code change and let the pipeline reapply:

```bash
git revert <bad-commit-hash>
git push origin main
```

OpenTofu will compute the diff between the reverted code and the current AWS state, then apply the changes needed to get back to the previous configuration.

**Option 2 — Manual targeted destroy and re-apply**

If only one resource is affected:

```bash
cd terraform/envs/production

# Remove just the broken resource from state and let Tofu recreate it
tofu destroy -target=aws_lambda_function.visitor_counter
tofu apply
```

> Avoid `tofu destroy` without `-target` — it will destroy the entire environment.

---

## Force-unlock a stuck Terraform state

**Symptoms:** A pipeline run fails with:

```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Cause:** A previous pipeline run was interrupted (cancelled, timed out, or crashed) while holding the state lock. The lock was never released.

**Steps:**

1. Confirm the lock is genuinely stale — check GitHub Actions to make sure no run is currently in progress for the affected environment.

2. Note the lock ID from the error message.

3. Force-unlock:

```bash
cd terraform/envs/staging   # or production

tofu init
tofu force-unlock <lock-id>
```

4. Re-trigger the failed pipeline run.

> **Warning:** Never force-unlock if another run is actively in progress — this can corrupt the state file.

---

## Manually invalidate the CloudFront cache

**Symptoms:** After a deployment, visitors are still seeing the old version of the site.

**Cause:** CloudFront edge locations have cached the old files. The pipeline normally invalidates the cache automatically, but the invalidation may have failed or not yet propagated.

**Steps:**

```bash
# Invalidate all files
aws cloudfront create-invalidation \
  --distribution-id DISTRIBUTION_ID \
  --paths "/*"

# Check invalidation status
aws cloudfront list-invalidations \
  --distribution-id DISTRIBUTION_ID
```

Invalidations typically propagate within 1–2 minutes. Status will show `Completed` when done.

> Distribution ID: `cd terraform/envs/production && tofu output cloudfront_distribution_id`

---

## Investigate Lambda errors

**Symptoms:** A CloudWatch alarm fires for `lambda-errors` or `lambda-duration`. Visitor counter is not working or is slow.

**Steps:**

**1. Check recent Lambda logs**

```bash
aws logs tail /aws/lambda/FUNCTION_NAME --since 1h --follow
```

Common log patterns to look for:
- `Task timed out` — the function exceeded its timeout (currently 3 seconds)
- `Unable to update item` — DynamoDB write failed (check DynamoDB capacity or permissions)
- `An error occurred (AccessDeniedException)` — IAM permissions issue

**2. Check the CloudWatch dashboard**

Open the production dashboard in the AWS console. The URL is available as a Terraform output:

```bash
cd terraform/envs/production && tofu output dashboard_url
```

Look at the Lambda Duration and Lambda Errors widgets to understand the scope and timing of the issue.

**3. Check DynamoDB**

```bash
# Verify the table exists and is in ACTIVE status
aws dynamodb describe-table --table-name TABLE_NAME --query 'Table.TableStatus'
```

**4. Test the API endpoint manually**

```bash
curl -s $(cd terraform/envs/production && tofu output -raw api_gateway_url)
```

Expected: a JSON response with the visitor count. A 5xx response confirms the Lambda is failing.

---

## Drain the Dead Letter Queue

**Symptoms:** The `dlq-messages` CloudWatch alarm fires. The DLQ widget on the dashboard shows messages accumulating.

**Cause:** The Lambda function failed on multiple invocations and exhausted all retries. The failed events are now sitting in the DLQ waiting for manual intervention.

**Steps:**

**1. Understand why the Lambda failed**

Check the Lambda logs (see [Investigate Lambda errors](#investigate-lambda-errors)) to understand the root cause before draining the queue — otherwise the same failures will repeat.

**2. View messages in the DLQ**

```bash
# Get the queue URL
QUEUE_URL=$(aws sqs get-queue-url --queue-name QUEUE_NAME --query 'QueueUrl' --output text)

# Peek at a message without consuming it
aws sqs receive-message --queue-url $QUEUE_URL --attribute-names All
```

**3. Once the root cause is fixed, purge the queue**

The DLQ messages are failed async invocations — there is no automatic replay mechanism here. Once the Lambda is working again, purge the stale messages:

```bash
aws sqs purge-queue --queue-url $QUEUE_URL
```

> Queue name: `cd terraform/envs/production && tofu output` (look for the SQS queue name in the state)

---

## Respond to a drift detection alert

**Symptoms:** A GitHub issue titled "Infrastructure drift detected" is opened by the `drift.yml` workflow. The issue body contains a Terraform plan diff.

**Cause:** The actual AWS infrastructure no longer matches the Terraform code. This usually happens when someone manually changed something in the AWS console.

**Steps:**

**1. Read the diff in the GitHub issue**

Resources marked with `~` were modified, `+` were added, `-` were deleted outside of Terraform.

**2. Decide how to resolve it**

- **The manual change was intentional and should be kept:** update the Terraform code to match the new state, open a PR, and merge it. The next drift check will be clean.

- **The manual change was accidental and should be reverted:** trigger a manual deploy from the main branch. OpenTofu will revert the AWS resource back to what the code describes.

```bash
# Trigger deploy manually from GitHub Actions UI, or:
git commit --allow-empty -m "chore: trigger deploy to fix drift"
git push origin main
```

**3. Close the GitHub issue** once the drift is resolved.

---

## Re-validate the ACM certificate

**Symptoms:** The CloudFront distribution returns a certificate error, or the CI/CD pipeline is stuck at `aws_acm_certificate_validation.resume: Still creating...`.

**Cause:** The DNS CNAME record required to validate the ACM certificate is missing or incorrect.

**Steps:**

**1. Find the required CNAME record**

```bash
aws acm describe-certificate \
  --certificate-arn CERTIFICATE_ARN \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord' \
  --output table
```

This outputs a `Name` and a `Value`. The CNAME record `Name → Value` must exist in your DNS provider (Namecheap).

> The certificate ARN is visible in the Terraform state or in the AWS Certificate Manager console (us-east-1 region).

**2. Add or correct the CNAME record in Namecheap**

- Log in to Namecheap → Domain List → Manage → Advanced DNS
- Add a new CNAME record:
  - **Host:** the `Name` value from step 1, with the root domain stripped (e.g. `_abc123.staging` instead of `_abc123.staging.fidele.samuth.com.`)
  - **Value:** the `Value` from step 1

**3. Wait for validation**

DNS propagation typically takes a few minutes to up to an hour. ACM polls automatically — once the record is found, the certificate status changes from `PENDING_VALIDATION` to `ISSUED`.

Monitor status:

```bash
watch -n 30 "aws acm describe-certificate \
  --certificate-arn CERTIFICATE_ARN \
  --region us-east-1 \
  --query 'Certificate.Status' \
  --output text"
```

**4. Re-run the pipeline** once the certificate is `ISSUED`.

---

## Restore DynamoDB table from Point-In-Time Recovery

**Symptoms:** The visitor counter data has been corrupted or accidentally deleted (e.g. a bad Lambda deployment overwrote the counter with a wrong value, or the table was accidentally cleared).

**Cause:** Point-In-Time Recovery (PITR) is enabled on the DynamoDB table, allowing restoration to any second within the past 35 days.

> **Important:** PITR restores to a **new table** — it does not overwrite the existing one. You will need to either import the restored data back into the original table, or update the Lambda to point to the restored table temporarily.

**Steps:**

**1. Identify the target restore time**

Determine the point in time you want to restore to — just before the corruption occurred. Use UTC.

```bash
# Check when PITR is available from (earliest restore point)
aws dynamodb describe-continuous-backups \
  --table-name TABLE_NAME \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription'
```

**2. Restore to a new table**

```bash
aws dynamodb restore-table-to-point-in-time \
  --source-table-name TABLE_NAME \
  --target-table-name TABLE_NAME-restored \
  --restore-date-time "2026-01-15T10:30:00Z"  # replace with your target time
```

**3. Wait for the restore to complete**

```bash
watch -n 10 "aws dynamodb describe-table \
  --table-name TABLE_NAME-restored \
  --query 'Table.TableStatus' \
  --output text"
```

Status will progress from `CREATING` to `ACTIVE` (typically a few minutes).

**4. Verify the restored data**

```bash
aws dynamodb get-item \
  --table-name TABLE_NAME-restored \
  --key '{"id": {"S": "visitors"}}'
```

Confirm the counter value looks correct.

**5. Copy the restored value back to the live table**

Once verified, write the correct value back to the original table:

```bash
# Get the count from the restored table
COUNT=$(aws dynamodb get-item \
  --table-name TABLE_NAME-restored \
  --key '{"id": {"S": "visitors"}}' \
  --query 'Item.count.N' \
  --output text)

# Write it back to the original table
aws dynamodb put-item \
  --table-name TABLE_NAME \
  --item "{\"id\": {\"S\": \"visitors\"}, \"count\": {\"N\": \"$COUNT\"}}"
```

**6. Clean up the restored table**

```bash
aws dynamodb delete-table --table-name TABLE_NAME-restored
```

**7. Import the restored table into Terraform state (optional)**

If you kept the restored table and renamed it instead, import it into Terraform to avoid drift:

```bash
cd terraform/envs/production
tofu import aws_dynamodb_table.visitor_counter TABLE_NAME
```

> Table name: `cd terraform/envs/production && tofu output` (not directly exposed — check the Terraform state or the AWS console)
