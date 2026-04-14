# Security

This document explains the security measures in place, written for readers who are not familiar with web or cloud security.

---

## HTTPS everywhere

All traffic to the website is encrypted using HTTPS (TLS 1.2 minimum). CloudFront automatically redirects any HTTP request to HTTPS, so it is not possible to visit the site over an unencrypted connection.

The SSL certificate is issued by AWS Certificate Manager (ACM) and renewed automatically — there is no risk of the certificate expiring.

---

## Security headers

When a browser receives a web page, the server can include **HTTP response headers** that instruct the browser on how to behave. These headers defend against common attack categories.

The following headers are set on every response via a CloudFront policy:

| Header | What it does |
|---|---|
| `Strict-Transport-Security` (HSTS) | Tells the browser to always use HTTPS for this domain, even if the user types `http://`. Prevents SSL stripping attacks. |
| `Content-Security-Policy` (CSP) | Defines exactly which sources the page is allowed to load scripts, styles, fonts, and images from. Prevents Cross-Site Scripting (XSS) attacks where an attacker injects malicious scripts. |
| `X-Frame-Options: DENY` | Prevents the page from being embedded in an `<iframe>` on another site. Stops clickjacking attacks where a victim is tricked into clicking something they can't see. |
| `X-Content-Type-Options` | Tells the browser not to guess the file type — only use what the server declares. Prevents MIME-sniffing attacks. |
| `Cross-Origin-Embedder-Policy` | Controls which cross-origin resources can be loaded. Required for certain browser security features. |
| `Cross-Origin-Opener-Policy` | Isolates the browsing context from other windows, preventing cross-origin attacks. |
| `Permissions-Policy` | Disables browser features the site doesn't need: camera, microphone, geolocation, payment. Reduces the attack surface. |

Additionally, the `Server` header (which would reveal that CloudFront is being used) is stripped from all responses. Disclosing server software versions helps attackers identify known vulnerabilities.

---

## Private S3 bucket

The S3 bucket that holds the website files is **not publicly accessible**. Only CloudFront can read from it, enforced by an **Origin Access Control (OAC)** policy.

This means:
- Visitors cannot bypass CloudFront and access files directly from S3
- Security headers set by CloudFront cannot be circumvented
- S3 access logs are not publicly readable

---

## Basic auth on staging

The staging environment (`staging.fidele.samuth.com`) is protected by HTTP basic authentication. A **CloudFront Function** runs on every incoming request and checks for a valid `Authorization` header before allowing access.

Anyone without the credentials receives a `401 Unauthorized` response and a login prompt.

This prevents:
- Search engines from indexing the staging site
- The public from confusing staging content with the production site
- Automated scanners from probing the staging environment

The credentials are stored as a GitHub Actions secret and injected at deploy time. They are never stored in the repository or in plain text.

---

## No long-lived cloud credentials

GitHub Actions needs to interact with AWS to deploy the infrastructure. A naive approach would be to create an AWS access key and store it as a GitHub secret — but access keys are long-lived credentials that remain valid until manually rotated, and if leaked they can be misused indefinitely.

Instead, the pipeline uses **OIDC (OpenID Connect)**. Here is how it works:

1. GitHub generates a short-lived, signed token for each workflow run
2. The workflow presents this token to AWS
3. AWS verifies the token was genuinely issued by GitHub, for this specific repository
4. AWS issues temporary credentials (valid for the duration of the workflow run only)

If the temporary credentials were somehow exposed, they would be useless within minutes.

---

## Least privilege IAM

The AWS IAM role used by GitHub Actions has only the permissions strictly required to plan and apply the infrastructure. It cannot:

- **Delete the S3 bucket** — `s3:DeleteBucket` is intentionally excluded. A `tofu destroy` would fail, preventing accidental deletion of the live website through CI/CD.
- **Delete the CloudFront distribution** — `cloudfront:DeleteDistribution` is excluded for the same reason.

If the infrastructure ever needs to be torn down, it must be done manually by someone with direct AWS access — a deliberate extra step to prevent accidents.

---

## Encrypted state file

OpenTofu keeps track of the infrastructure it manages in a **state file** — a JSON document that describes every resource and its current configuration. This file can contain sensitive values (API keys, passwords, etc.).

The state file is stored in S3 with:
- **KMS encryption** — encrypted with a dedicated key managed by AWS
- **Versioning** — every version of the state file is kept, allowing recovery from accidental corruption
- **Native S3 locking** — prevents two pipeline runs from modifying the state simultaneously, which could corrupt it

---

## Static analysis in CI/CD

Every pull request runs two automated security scanners before the code can be merged:

**Checkov** scans the Terraform infrastructure code against hundreds of security rules — checking for things like unencrypted storage, overly permissive IAM policies, missing access logs, and public-facing resources that should be private. Results are uploaded to the GitHub Security tab.

**Bandit** scans the Python Lambda code for common security issues — hardcoded credentials, use of insecure functions, SQL injection patterns, etc.

**OWASP ZAP** runs a passive scan against the deployed staging site on every deployment and every week. It checks the live site for security misconfigurations — missing headers, exposed version information, insecure cookies, etc.

---

## Pre-commit hooks

Developers running the code locally have pre-commit hooks configured that run TFLint, Checkov, and Bandit automatically before each commit. This catches issues before they even reach a pull request.
