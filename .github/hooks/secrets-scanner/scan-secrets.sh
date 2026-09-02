#!/bin/bash
#!/bin/bash

# Secrets Scanner Hook
# Scans files modified during a Copilot coding agent session for accidentally
# leaked secrets, credentials, and sensitive data before they are committed.
#
# Environment variables:
#   SCAN_MODE          - "warn" (log only) or "block" (exit non-zero on findings) (default: warn)
#   SCAN_SCOPE         - "diff" (changed files only) or "staged" (staged files) (default: diff)
#   SKIP_SECRETS_SCAN  - "true" to disable scanning entirely (default: unset)
#   SECRETS_LOG_DIR    - Directory for scan logs (default: logs/copilot/secrets)
#   SECRETS_ALLOWLIST  - Comma-separated list of patterns to ignore (default: unset)

set -euo pipefail

# ---------------------------------------------------------------------------
# Secret detection patterns
#
# Each entry: "PATTERN_NAME|SEVERITY|REGEX"
# Severity levels: critical, high, medium
# ---------------------------------------------------------------------------
PATTERNS=(
  # Cloud provider credentials
  "AWS_ACCESS_KEY|critical|AKIA[0-9A-Z]{16}"
  "AWS_SECRET_KEY|critical|aws_secret_access_key[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9/+=]{40}"
  "AZURE_CLIENT_SECRET|critical|azure[_-]?client[_-]?secret[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_~.-]{34,}"

  # GitHub tokens
  "GITHUB_PAT|critical|ghp_[0-9A-Za-z]{36}"
  "GITHUB_OAUTH|critical|gho_[0-9A-Za-z]{36}"
  "GITHUB_APP_TOKEN|critical|ghs_[0-9A-Za-z]{36}"
  "GITHUB_REFRESH_TOKEN|critical|ghr_[0-9A-Za-z]{36}"
  "GITHUB_FINE_GRAINED_PAT|critical|github_pat_[0-9A-Za-z_]{82}"

  # Private keys
  "PRIVATE_KEY|critical|-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY-----"
  "PGP_PRIVATE_BLOCK|critical|-----BEGIN PGP PRIVATE KEY BLOCK-----"

  # Generic secrets and tokens
  "GENERIC_SECRET|high|(secret|token|password|passwd|pwd|api[_-]?key|apikey|access[_-]?key|auth[_-]?token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_/+=~.-]{8,}"
  "CONNECTION_STRING|high|(mongodb(\\+srv)?|postgres(ql)?|mysql|redis|amqp|mssql(\\+pyodbc)?)://[^[:space:]'\"]{10,}"
  "BEARER_TOKEN|medium|[Bb]earer[[:space:]]+[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"

  # Azure DevOps Personal Access Tokens (base62, 52–86 chars)
  "AZURE_DEVOPS_PAT|critical|(^|[^A-Za-z0-9])(PAT|_PAT|ADO[_-]?PAT|FEED[_-]?READ[_-]?PAT)[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9/+=]{40,}"

  # SonarQube tokens
  "SONARQUBE_TOKEN|critical|squ_[0-9a-f]{40}"

  # Databricks Personal Access Tokens
  "DATABRICKS_PAT|critical|dapi[0-9a-f]{32,}"

  # OIDC / OAuth client secrets (env var assignments)
  "OIDC_CLIENT_SECRET|high|OIDC_CLIENT_SECRET[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_/+=~.-]{8,}"

  # Kafka client secrets (env var assignments)
  "KAFKA_CLIENT_SECRET|high|KAFKA_(IN|OUT)_CLIENT_SECRET[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_/+=~.-]{8,}"

  # Monitoring / Observability client secrets (env var assignments)
  "MO_CLIENT_SECRET|high|MO_CLIENT_SECRET[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9_/+=~.-]{8,}"

  # Azure Container Registry admin passwords
  "ACR_ADMIN_PASSWORD|critical|ACR_ADMIN_PASSWORD[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9/+=~.-]{20,}"

  # Azure Storage Account access keys (base64, typically ending in ==)
  "AZURE_STORAGE_KEY|critical|STORAGE_ACCOUNT_ACCESS_KEY[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9/+=]{40,}"

  # PFX / PKCS12 certificates encoded as base64
  "PFX_BASE64_CERT|high|PFX_BASE64[[:space:]]*[:=][[:space:]]*['\"]?MII[A-Za-z0-9/+=]{100,}"

  # Mend / WhiteSource API keys and project tokens (64-char hex)
  "MEND_API_KEY|high|(MEND_API_KEY|MEND_PROJECTTOKEN|MEND_USERKEY)[[:space:]]*[:=][[:space:]]*['\"]?[0-9a-f]{64}"

  # pyodbc connection strings with embedded credentials (user:pass@host)
  "PYODBC_CREDENTIALS|critical|pyodbc://[^@:[:space:]]*:[^@[:space:]]*@[^[:space:]'\"]{10,}"

  # Azure subscription and tenant IDs (GUIDs)
  "AZURE_GUID_SECRET|medium|(SUBSCRIPTION_ID|TENANT_ID|CLIENT_ID)[[:space:]]*[:=][[:space:]]*['\"]?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

  # Database passwords in connection strings (user:password@ pattern)
  "DB_PASSWORD_IN_URI|critical|(sqladmin|sa|admin|root|db_user):[A-Za-z0-9_!@#$%^&*+=~.-]{6,}@[A-Za-z0-9._-]+"

  # DEP / OIDC SSO authority and issuer URLs (internal SSO endpoints)
  "SSO_AUTHORITY_URL|medium|(STS_AUTHORITY|OIDC_ISSUER)[[:space:]]*[:=][[:space:]]*['\"]?https?://sso\.[^[:space:]'\"]{10,}"

  # DEP Service Discovery URLs (internal platform endpoints)
  "SERVICE_DISCOVERY_URL|medium|SERVICE_DISCOVERY_URL[[:space:]]*[:=][[:space:]]*['\"]?https?://sde\.[^[:space:]'\"]{10,}"

  # Kafka pool identifiers (DEP platform-assigned pool IDs)
  "KAFKA_POOL_ID|medium|POOL_ID[[:space:]]*[:=][[:space:]]*['\"]?pool-[A-Za-z0-9]{4,}"

  # OpenTelemetry / Monitoring internal endpoints
  "OTEL_INTERNAL_ENDPOINT|medium|(MO_HTTP_ENDPOINT|OTEL.*ENDPOINT)[[:space:]]*[:=][[:space:]]*['\"]?https?://opentel[^[:space:]'\"]{10,}"

  # API subscription keys embedded in URLs or env vars
  "API_SUBSCRIPTION_KEY|high|subscription[_-]key[[:space:]]*[:=][[:space:]]*['\"]?[A-Za-z0-9]{20,}"

  # npm tokens
  "NPM_TOKEN|high|npm_[0-9A-Za-z]{36}"

  # JWT (long, structured tokens)
  "JWT_TOKEN|medium|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"

  # IP addresses with ports (possible internal services)
  "INTERNAL_IP_PORT|medium|(^|[^.0-9])(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}):[0-9]{2,5}([^0-9]|$)"
)

if [[ "${SKIP_SECRETS_SCAN:-}" == "true" ]]; then
  echo "⏭️  Secrets scan skipped (SKIP_SECRETS_SCAN=true)"
  exit 0
fi

# Ensure we are in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "⚠️  Not in a git repository, skipping secrets scan"
  exit 0
fi

MODE="${SCAN_MODE:-warn}"
SCOPE="${SCAN_SCOPE:-diff}"
LOG_DIR="${SECRETS_LOG_DIR:-logs/copilot/secrets}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FINDING_COUNT=0

mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/scan.log"

# Collect files to scan based on scope
FILES=()
if [[ "$SCOPE" == "staged" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
  done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)
else
  while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
  done < <(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null || git diff --name-only --diff-filter=ACMR 2>/dev/null)
  # Also include untracked new files (created during the session, not yet in HEAD)
  while IFS= read -r f; do
    [[ -n "$f" ]] && FILES+=("$f")
  done < <(git ls-files --others --exclude-standard 2>/dev/null)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "✨ No modified files to scan"
  printf '{"timestamp":"%s","event":"scan_complete","mode":"%s","scope":"%s","status":"clean","files_scanned":0}\n' \
    "$TIMESTAMP" "$MODE" "$SCOPE" >> "$LOG_FILE"
  exit 0
fi

# Parse allowlist into an array
ALLOWLIST=()
if [[ -n "${SECRETS_ALLOWLIST:-}" ]]; then
  IFS=',' read -ra ALLOWLIST <<< "$SECRETS_ALLOWLIST"
fi

is_allowlisted() {
  local match="$1"
  for pattern in "${ALLOWLIST[@]}"; do
    pattern=$(printf '%s' "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [[ -z "$pattern" ]] && continue
    if [[ "$match" == *"$pattern"* ]]; then
      return 0
    fi
  done
  return 1
}

# Binary file detection: skip files that are not text
is_text_file() {
  local filepath="$1"
  [[ -f "$filepath" ]] && file --brief --mime-type "$filepath" 2>/dev/null | grep -q "^text/" && return 0
  # Fallback: check common text extensions
  case "$filepath" in
    *.md|*.txt|*.json|*.yaml|*.yml|*.xml|*.toml|*.ini|*.cfg|*.conf|\
    *.sh|*.bash|*.zsh|*.ps1|*.bat|*.cmd|\
    *.py|*.rb|*.js|*.ts|*.jsx|*.tsx|*.go|*.rs|*.java|*.kt|*.cs|*.cpp|*.c|*.h|\
    *.php|*.swift|*.scala|*.r|*.R|*.lua|*.pl|*.ex|*.exs|*.hs|*.ml|\
    *.html|*.css|*.scss|*.less|*.svg|\
    *.sql|*.graphql|*.proto|\
    *.env|*.env.*|*.properties|\
    Dockerfile*|Makefile*|Vagrantfile|Gemfile|Rakefile)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# Escape a string value for safe embedding in a JSON string literal
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Store findings as tab-separated records
FINDINGS=()

scan_file() {
  local filepath="$1"
  # read_path: the actual file to scan; defaults to filepath (working tree)
  # When SCOPE=staged, callers pass a temp file with the staged content instead
  local read_path="${2:-$1}"

  # Skip if source does not exist (e.g., deleted)
  [[ -f "$read_path" ]] || return 0

  # Skip binary files (type detection uses the original path for MIME lookup)
  if ! is_text_file "$filepath"; then
    return 0
  fi

  # Skip common non-sensitive files
  case "$filepath" in
    *.lock|package-lock.json|yarn.lock|pnpm-lock.yaml|Cargo.lock|go.sum|*.sum)
      return 0 ;;
  esac

  for entry in "${PATTERNS[@]}"; do
    IFS='|' read -r pattern_name severity regex <<< "$entry"

    while IFS=: read -r line_num matched_line; do
      # Extract the matched fragment
      local match
      match=$(printf '%s\n' "$matched_line" | grep -oE "$regex" 2>/dev/null | head -1)
      [[ -z "$match" ]] && continue

      # Strip leading boundary characters from patterns that use boundary guards
      # (e.g., AZURE_DEVOPS_PAT starts with (^|[^A-Za-z0-9]), INTERNAL_IP_PORT starts with (^|[^.0-9]))
      match=$(printf '%s' "$match" | sed 's/^[^A-Za-z0-9_$"'"'"'-]*//')
      [[ -z "$match" ]] && continue

      # Further strip IP:port matches to just the address
      if [[ "$pattern_name" == "INTERNAL_IP_PORT" ]]; then
        match=$(printf '%s' "$match" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+')
        [[ -z "$match" ]] && continue
      fi

      # Check allowlist
      if [[ ${#ALLOWLIST[@]} -gt 0 ]] && is_allowlisted "$match"; then
        continue
      fi

      # Skip if this looks like a placeholder or example
      if printf '%s\n' "$match" | grep -qiE '(example|placeholder|your[_-]|xxx|changeme|TODO|FIXME|replace[_-]?me|dummy|fake|test[_-]?key|sample)'; then
        continue
      fi

      # Redact the match for safe logging: show first 4 and last 4 chars
      local redacted
      if [[ ${#match} -le 12 ]]; then
        redacted="[REDACTED]"
      else
        redacted="${match:0:4}...${match: -4}"
      fi

      FINDINGS+=("$filepath	$line_num	$pattern_name	$severity	$redacted")
      FINDING_COUNT=$((FINDING_COUNT + 1))
    done < <(grep -nE "$regex" "$read_path" 2>/dev/null || true)
  done
}

echo "🔍 Scanning ${#FILES[@]} modified file(s) for secrets..."

for filepath in "${FILES[@]}"; do
  if [[ "$SCOPE" == "staged" ]]; then
    # Scan the staged (index) version to match what will actually be committed
    _tmpfile=$(mktemp)
    git show :"$filepath" > "$_tmpfile" 2>/dev/null || true
    scan_file "$filepath" "$_tmpfile"
    rm -f "$_tmpfile"
  else
    scan_file "$filepath"
  fi
done

# Log results
if [[ $FINDING_COUNT -gt 0 ]]; then
  echo ""
  echo "⚠️  Found $FINDING_COUNT potential secret(s) in modified files:"
  echo ""
  printf "  %-40s %-6s %-28s %s\n" "FILE" "LINE" "PATTERN" "SEVERITY"
  printf "  %-40s %-6s %-28s %s\n" "----" "----" "-------" "--------"

  # Build JSON findings array and print table
  FINDINGS_JSON="["
  FIRST=true
  for finding in "${FINDINGS[@]}"; do
    IFS=$'\t' read -r fpath fline pname psev redacted <<< "$finding"

    printf "  %-40s %-6s %-28s %s\n" "$fpath" "$fline" "$pname" "$psev"

    if [[ "$FIRST" != "true" ]]; then
      FINDINGS_JSON+=","
    fi
    FIRST=false

    # Build JSON safely without requiring jq; escape path and match values
    FINDINGS_JSON+="{\"file\":\"$(json_escape "$fpath")\",\"line\":$fline,\"pattern\":\"$pname\",\"severity\":\"$psev\",\"match\":\"$(json_escape "$redacted")\"}"
  done
  FINDINGS_JSON+="]"

  echo ""

  # Write structured log entry
  printf '{"timestamp":"%s","event":"secrets_found","mode":"%s","scope":"%s","files_scanned":%d,"finding_count":%d,"findings":%s}\n' \
    "$TIMESTAMP" "$MODE" "$SCOPE" "${#FILES[@]}" "$FINDING_COUNT" "$FINDINGS_JSON" >> "$LOG_FILE"

  if [[ "$MODE" == "block" ]]; then
    echo "🚫 Session blocked: resolve the findings above before committing."
    echo "   Set SCAN_MODE=warn to log without blocking, or add patterns to SECRETS_ALLOWLIST."
    exit 1
  else
    echo "💡 Review the findings above. Set SCAN_MODE=block to prevent commits with secrets."
  fi
else
  echo "✅ No secrets detected in ${#FILES[@]} scanned file(s)"
  printf '{"timestamp":"%s","event":"scan_complete","mode":"%s","scope":"%s","status":"clean","files_scanned":%d}\n' \
    "$TIMESTAMP" "$MODE" "$SCOPE" "${#FILES[@]}" >> "$LOG_FILE"
fi

exit 0