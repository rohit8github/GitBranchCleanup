---
name: 'Secrets Scanner'
description: 'Scans files modified during a Copilot coding agent session for leaked secrets, credentials, and sensitive data'
tags: ['security', 'secrets', 'scanning', 'session-end']
---

# Secrets Scanner Hook

Scans files modified during a GitHub Copilot coding agent session for accidentally leaked secrets, credentials, API keys, and other sensitive data before they are committed.

## Overview

AI coding agents generate and modify code rapidly, which increases the risk of hardcoded secrets slipping into the codebase. This hook acts as a safety net by scanning all modified files at session end for 30+ categories of secret patterns, including:

- **Cloud credentials**: AWS access keys, Azure client secrets, Azure DevOps PATs, Azure storage keys
- **Platform tokens**: GitHub PATs, SonarQube tokens, Databricks PATs, npm tokens
- **Private keys & certificates**: RSA, EC, OpenSSH, PGP, DSA private key blocks, PFX/PKCS12 base64 certs
- **Connection strings**: Database URIs (PostgreSQL, AzureSQL), embedded DB credentials
- **Service secrets**: OIDC client secrets, Kafka client secrets, monitoring/observability secrets, ACR admin passwords
- **Code scanning**: Mend/WhiteSource API keys and project tokens
- **Generic secrets**: API keys, passwords, bearer tokens, JWTs
- **DEP platform**: SSO/OIDC issuer URLs, service discovery URLs, Kafka pool IDs, OpenTelemetry endpoints, API subscription keys
- **Infrastructure identifiers**: Azure subscription/tenant/client GUIDs, private IP addresses with ports

## Features

- **Two scan modes**: `warn` (log only) or `block` (exit non-zero to prevent commit)
- **Two scan scopes**: `diff` (modified files vs HEAD) or `staged` (git-staged files only)
- **Smart filtering**: Skips binary files, lock files, and placeholder/example values
- **Allowlist support**: Exclude known false positives via `SECRETS_ALLOWLIST`
- **Structured logging**: JSON Lines output for integration with monitoring tools
- **Redacted output**: Findings are truncated in logs to avoid re-exposing secrets
- **Zero dependencies**: Uses only standard Unix tools (`grep`, `file`, `git`)

## Installation

1. Copy the hook folder to your repository:

   ```bash
   cp -r hooks/secrets-scanner .github/hooks/
   ```

2. Ensure the script is executable:

   ```bash
   chmod +x .github/hooks/secrets-scanner/scan-secrets.sh
   ```

   On Windows PowerShell, use Git Bash for `chmod`, or run:

   ```bash
   git update-index --chmod=+x .github/hooks/secrets-scanner/scan-secrets.sh
   ```

3. Enable Git pre-commit hooks for local commits (including Visual Studio commits):

   ```bash
   git config core.hooksPath .github/hooks
   ```

   This repository includes `.github/hooks/pre-commit`, which invokes the secrets scanner before each commit.

   For Visual Studio on Windows, also install the local shim hook:

   ```powershell
   .\install-hooks.ps1
   ```

   This creates `.git/hooks/pre-commit` that forwards to the versioned hook under `.github/hooks/`.

4. Create the logs directory and add it to `.gitignore`:

   ```bash
   mkdir -p logs/copilot/secrets
   echo "logs/" >> .gitignore
   ```

5. Commit the hook configuration to your repository's default branch.

## Configuration

The hook is configured in `hooks.json` to run on the `Stop` event (triggered when a Copilot coding agent session ends):

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": ".github/hooks/secrets-scanner/scan-secrets.sh",
        "cwd": ".",
        "env": {
          "SCAN_MODE": "warn",
          "SCAN_SCOPE": "diff"
        },
        "timeout": 30
      }
    ]
  }
}
```

### Environment Variables

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `SCAN_MODE` | `warn`, `block` | `warn` | `warn` logs findings only; `block` exits non-zero to prevent auto-commit |
| `SCAN_SCOPE` | `diff`, `staged` | `diff` | `diff` scans uncommitted changes vs HEAD; `staged` scans only staged files |
| `SKIP_SECRETS_SCAN` | `true` | unset | Disable the scanner entirely |
| `SECRETS_LOG_DIR` | path | `logs/copilot/secrets` | Directory where scan logs are written |
| `SECRETS_ALLOWLIST` | comma-separated | unset | Patterns to ignore (e.g., `test_key_123,example.com`) |

## How It Works

1. When a Copilot coding agent session ends, the hook executes
2. Collects all modified files using `git diff` (respects the configured scope)
3. Filters out binary files and lock files
4. Scans each text file line-by-line against 30+ regex patterns for known secret formats
5. Skips matches that look like placeholders (e.g., values containing `example`, `changeme`, `your_`)
6. Checks matches against the allowlist if configured
7. Reports findings with file path, line number, pattern name, and severity
8. Writes a structured JSON log entry for audit purposes
9. In `block` mode, exits non-zero to signal the agent to stop before committing

## Detected Secret Patterns

### Cloud & Platform Credentials

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `AWS_ACCESS_KEY` | critical | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_KEY` | critical | `aws_secret_access_key = wJalr...` |
| `AZURE_CLIENT_SECRET` | critical | `azure_client_secret = ...` |
| `AZURE_DEVOPS_PAT` | critical | `PAT=3LBWUtk5aI6X...` |
| `AZURE_STORAGE_KEY` | critical | `STORAGE_ACCOUNT_ACCESS_KEY = yTcfk9Q...` |
| `ACR_ADMIN_PASSWORD` | critical | `ACR_ADMIN_PASSWORD = VQRYBN7f...` |
| `AZURE_GUID_SECRET` | medium | `SUBSCRIPTION_ID = 266aacf1-7fcf-...` |

### Platform Tokens

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `GITHUB_PAT` | critical | `ghp_xxxxxxxxxxxx...` |
| `GITHUB_OAUTH` | critical | `gho_xxxxxxxxxxxx...` |
| `GITHUB_APP_TOKEN` | critical | `ghs_xxxxxxxxxxxx...` |
| `GITHUB_REFRESH_TOKEN` | critical | `ghr_xxxxxxxxxxxx...` |
| `GITHUB_FINE_GRAINED_PAT` | critical | `github_pat_...` |
| `SONARQUBE_TOKEN` | critical | `squ_b2334393b261...` |
| `DATABRICKS_PAT` | critical | `dapie1d2ee1744bf...` |
| `NPM_TOKEN` | high | `npm_...` |

### Private Keys & Certificates

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `PRIVATE_KEY` | critical | `-----BEGIN RSA PRIVATE KEY-----` |
| `PGP_PRIVATE_BLOCK` | critical | `-----BEGIN PGP PRIVATE KEY BLOCK-----` |
| `PFX_BASE64_CERT` | high | `PFX_BASE64 = MIIKUAIBAz...` |

### Connection Strings & Database Credentials

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `CONNECTION_STRING` | high | `mssql+pyodbc://user:pass@host/db` |
| `PYODBC_CREDENTIALS` | critical | `pyodbc://sqladmin:pass@host...` |
| `DB_PASSWORD_IN_URI` | critical | `sqladmin:1zpnW590@host...` |

### Service Secrets (env var assignments)

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `OIDC_CLIENT_SECRET` | high | `OIDC_CLIENT_SECRET = 9LAGOcts...` |
| `KAFKA_CLIENT_SECRET` | high | `KAFKA_IN_CLIENT_SECRET = 9LAGOcts...` |
| `MO_CLIENT_SECRET` | high | `MO_CLIENT_SECRET = 5F7FOSuZ...` |
| `MEND_API_KEY` | high | `MEND_API_KEY = 8844afcbf78a...` |

### DEP Platform (internal infrastructure URLs & identifiers)

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `SSO_AUTHORITY_URL` | medium | `STS_AUTHORITY = https://sso.dep.shell/...` |
| `SERVICE_DISCOVERY_URL` | medium | `SERVICE_DISCOVERY_URL = https://sde.dep.shell/...` |
| `KAFKA_POOL_ID` | medium | `POOL_ID = pool-w3ONl` |
| `OTEL_INTERNAL_ENDPOINT` | medium | `MO_HTTP_ENDPOINT = https://opentel-http.dep.shell/...` |
| `API_SUBSCRIPTION_KEY` | high | `subscription-key = dec65ac3993f...` |


### Generic Secrets

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `GENERIC_SECRET` | high | `api_key = "sk-..."` |
| `BEARER_TOKEN` | medium | `Bearer eyJhbG...` |
| `JWT_TOKEN` | medium | `eyJhbGci...` |

### Infrastructure

| Pattern | Severity | Example Match |
|---------|----------|---------------|
| `INTERNAL_IP_PORT` | medium | `192.168.1.1:8080` |

See the full list in `scan-secrets.sh`.

## Example Output

### Clean scan

```
🔍 Scanning 5 modified file(s) for secrets...
✅ No secrets detected in 5 scanned file(s)
```

### Findings detected (warn mode)

```
🔍 Scanning 3 modified file(s) for secrets...

⚠️  Found 2 potential secret(s) in modified files:

  FILE                                     LINE   PATTERN                      SEVERITY
  ----                                     ----   -------                      --------
  .env                                     2      AZURE_DEVOPS_PAT             critical
  docker_configs/dev.env                   20     DB_PASSWORD_IN_URI           critical

💡 Review the findings above. Set SCAN_MODE=block to prevent commits with secrets.
```

### Findings detected (block mode)

```
🔍 Scanning 3 modified file(s) for secrets...

⚠️  Found 1 potential secret(s) in modified files:

  FILE                                     LINE   PATTERN                      SEVERITY
  ----                                     ----   -------                      --------
  backend/docker/envs/dev/base.env         22     KAFKA_CLIENT_SECRET          high

🚫 Session blocked: resolve the findings above before committing.
   Set SCAN_MODE=warn to log without blocking, or add patterns to SECRETS_ALLOWLIST.
```

## Log Format

Scan events are written to `logs/copilot/secrets/scan.log` in JSON Lines format:

```json
{"timestamp":"2026-03-13T10:30:00Z","event":"secrets_found","mode":"warn","scope":"diff","files_scanned":3,"finding_count":2,"findings":[{"file":"src/config.ts","line":12,"pattern":"GITHUB_PAT","severity":"critical","match":"ghp_...xyz1"}]}
```

```json
{"timestamp":"2026-03-13T10:30:00Z","event":"scan_complete","mode":"warn","scope":"diff","status":"clean","files_scanned":5}
```

## Customization

- **Add custom patterns**: Edit the `PATTERNS` array in `scan-secrets.sh` to add project-specific secret formats
- **Adjust sensitivity**: Change severity levels or remove patterns that generate false positives
- **Allowlist known values**: Use `SECRETS_ALLOWLIST` for test fixtures or known safe patterns
- **Change log location**: Set `SECRETS_LOG_DIR` to route logs to your preferred directory

## Disabling

To temporarily disable the scanner:

- Set `SKIP_SECRETS_SCAN=true` in the hook environment
- Or remove the `Stop` entry from `hooks.json`

## Limitations

- Pattern-based detection; does not perform entropy analysis or contextual validation
- May produce false positives for test fixtures or example code (use the allowlist to suppress these)
- Scans only text files; binary secrets (keystores, certificates in DER format) are not detected
- Requires `git` to be available in the execution environment