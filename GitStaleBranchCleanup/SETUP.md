# Quick Setup Guide

## 1. Prerequisites
- .NET 8.0 SDK installed
- GitHub Personal Access Token with appropriate permissions

## 2. Setup Steps

### Step 1: Configure the Application
1. Copy `appsettings.sample.json` to `appsettings.json`
2. Edit `appsettings.json` with your details:
   ```json
   {
     "GitConfig": {
       "RepositoryUrl": "https://github.com/your-org/your-repo",
       "PersonalAccessToken": "your_actual_pat_token",
       "Owner": "your-org",
       "Repository": "your-repo"
     }
   }
   ```

### Step 2: Create GitHub Personal Access Token
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Click "Generate new token (classic)"
3. Select scopes:
   - `repo` (for private repos) or `public_repo` (for public repos)
   - `delete_repo` (for branch deletion)
4. Copy the generated token to your `appsettings.json`

### Step 3: Run the Application
Choose one of these methods:

**Option A: Command Line**
```bash
dotnet run
```

**Option B: Windows Batch File**
```bash
run.bat
```

**Option C: PowerShell Script**
```powershell
./run.ps1
```

## 3. Configuration Options

### Branch Exclusion Patterns
- `main`, `master`, `develop` - Exact matches
- `release/*`, `hotfix/*` - Wildcard patterns
- Add your own patterns to the `ExcludePatterns` array

### Safety Settings
- `DaysThreshold`: Days before a branch is considered stale (default: 30)
- `DeletionLimitPerRun`: Maximum branches to delete per execution (default: 10)

## 4. What the Tool Does
1. **Connects** to your GitHub repository
2. **Fetches** all non-protected branches
3. **Analyzes** each branch for staleness
4. **Generates** an Excel report with detailed information
5. **Asks for confirmation** before deleting any branches
6. **Safely deletes** stale branches (with limits)

## 5. Safety Features
- Never deletes protected branches
- Skips branches with active pull requests
- Respects exclude patterns
- Limits deletions per run
- Requires user confirmation
- Generates audit trail (Excel report)

## 6. Troubleshooting
- **Authentication Error**: Check your PAT token and permissions
- **Repository Not Found**: Verify owner/repository names
- **Permission Denied**: Ensure token has required scopes
- **Rate Limiting**: Wait and try again, or contact GitHub support

## 7. First Run Checklist
- [ ] .NET 8.0 SDK installed
- [ ] GitHub PAT created with correct scopes
- [ ] `appsettings.json` configured with real values
- [ ] Repository owner/name verified
- [ ] Exclude patterns reviewed and customized
- [ ] Ready to review Excel report before confirming deletions
