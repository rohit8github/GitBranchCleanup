# GitStaleBranchCleanup

A powerful C# console application designed to help you automatically identify and cleanup stale branches in your GitHub repositories. This tool provides a comprehensive workflow to analyze branch activity, generate detailed reports, and safely delete unused branches.

## Features

- **Configurable Git Repository Access**: Supports GitHub repositories with Personal Access Token authentication
- **Comprehensive Branch Analysis**: Lists all non-protected branches with detailed information
- **Excel Report Generation**: Creates detailed Excel reports with branch analysis data
- **Smart Filtering**: Excludes branches based on configurable patterns and active pull requests
- **Safe Deletion Process**: Implements deletion limits and user confirmation for safety
- **Modular Architecture**: Clean, maintainable code structure with dependency injection patterns

## Prerequisites

- .NET 8.0 or later
- GitHub repository access
- GitHub Personal Access Token with appropriate permissions:
  - `repo` scope for private repositories
  - `public_repo` scope for public repositories
  - `delete_repo` scope for branch deletion

## Installation

1. Clone or download this repository
2. Navigate to the project directory
3. Restore dependencies:
   ```bash
   dotnet restore
   ```
4. Build the project:
   ```bash
   dotnet build
   ```

## Configuration

Before running the application, you need to configure the `appsettings.json` file:

```json
{
  "GitConfig": {
    "RepositoryUrl": "https://github.com/your-org/your-repo",
    "PersonalAccessToken": "your-pat-token-here",
    "Owner": "your-org",
    "Repository": "your-repo"
  },
  "CleanupConfig": {
    "DaysThreshold": 30,
    "DeletionLimitPerRun": 10,
    "ExcludePatterns": [
      "main",
      "master", 
      "develop",
      "release/*",
      "releases/*",
      "hotfix/*"
    ],
    "OutputExcelFile": "stale-branches-report.xlsx"
  }
}
```

### Configuration Options

#### GitConfig
- **RepositoryUrl**: Full URL to your GitHub repository
- **PersonalAccessToken**: Your GitHub Personal Access Token
- **Owner**: GitHub username or organization name
- **Repository**: Repository name

#### CleanupConfig
- **DaysThreshold**: Number of days after which a branch is considered stale (default: 30)
- **DeletionLimitPerRun**: Maximum number of branches to delete in one execution (default: 10)
- **ExcludePatterns**: List of branch name patterns to exclude from deletion
  - Supports wildcards (e.g., `release/*` matches any branch starting with "release/")
  - Exact matches (e.g., `main` matches only the "main" branch)
- **OutputExcelFile**: Name of the Excel report file to generate

## Usage

1. **Configure the application** by editing `appsettings.json` with your repository details and preferences.

2. **Run the application**:
   ```bash
   dotnet run
   ```

3. **Review the analysis**: The tool will:
   - Connect to your GitHub repository
   - Fetch all non-protected branches
   - Analyze each branch for staleness
   - Generate an Excel report with detailed information
   - Display a summary in the console

4. **Review the Excel report**: Open the generated Excel file to see:
   - **BranchName**: Name of the branch
   - **BranchUrl**: Direct link to the branch on GitHub
   - **LastCommitDate**: Date of the last commit
   - **ActivePullRequest**: Whether the branch has open pull requests
   - **IsStale**: Whether the branch is considered stale
   - **LastCommitAuthor**: Author of the last commit

5. **Confirm deletion**: If stale branches are found, you'll be prompted to confirm deletion.

## Safety Features

- **Protected Branch Exclusion**: Automatically skips protected branches
- **Pattern-Based Exclusion**: Configurable patterns to exclude important branches
- **Active PR Check**: Branches with open pull requests are never deleted
- **Deletion Limits**: Configurable limit on how many branches to delete per run
- **User Confirmation**: Requires explicit user confirmation before deletion
- **Detailed Logging**: Comprehensive console output for transparency

## Branch Exclusion Logic

A branch is excluded from deletion if:
1. It's a protected branch (GitHub repository setting)
2. It matches any pattern in the `ExcludePatterns` configuration
3. It has active (open) pull requests
4. Its last commit is within the configured `DaysThreshold`

## Excel Report Structure

The generated Excel report includes:
- **Headers**: Clearly labeled columns with bold formatting
- **Data Highlighting**: Stale branches are highlighted in yellow
- **Auto-fitted Columns**: Columns are automatically sized for readability
- **Comprehensive Data**: All relevant branch information in one place

## Error Handling

The application includes robust error handling for:
- Network connectivity issues
- GitHub API rate limiting
- Invalid configuration
- Authentication problems
- File I/O operations

## Example Workflow

```bash
# 1. Configure appsettings.json
# 2. Run the application
dotnet run

# Output example:
=== Git Stale Branch Cleanup Tool ===

Repository: my-org/my-repo
Days threshold: 30
Deletion limit per run: 10
Exclude patterns: main, master, develop, release/*, releases/*, hotfix/*

Fetching branches from my-org/my-repo...
Found 25 non-protected branches.
Excluding branch (pattern match): main
Excluding branch (active PR): feature/new-api
Stale branch found: old-feature (last commit: 2024-07-15)
Stale branch found: abandoned-experiment (last commit: 2024-06-20)

Excel report generated: stale-branches-report.xlsx
Total branches: 25
Stale branches: 5

Analysis complete. Check 'stale-branches-report.xlsx' for detailed report.

Do you want to proceed with branch deletion? (y/N): y

Found 5 stale branches.
Will delete up to 10 branches in this run.

Branches to be deleted:
  - old-feature (last commit: 2024-07-15)
  - abandoned-experiment (last commit: 2024-06-20)
  - ...

Do you want to proceed with deletion? (y/N): y

Starting branch deletion...
Successfully deleted branch: old-feature
Successfully deleted branch: abandoned-experiment
...

Deletion completed. 5/5 branches deleted successfully.

Tool execution completed.
Press any key to exit...
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify your Personal Access Token is correct
   - Ensure the token has appropriate scopes
   - Check if the token has expired

2. **Repository Not Found**
   - Verify the Owner and Repository names are correct
   - Ensure you have access to the repository

3. **Permission Denied**
   - Ensure your token has `delete_repo` scope for branch deletion
   - Verify you have admin/write access to the repository

4. **Excel File Issues**
   - Ensure the output directory is writable
   - Close any existing Excel files with the same name

### Debug Mode

Run the application with debug flag for detailed error information:
```bash
dotnet run -- --debug
```

## Architecture

The application follows a clean, modular architecture:

- **Models**: Data structures (`BranchInfo`, configuration classes)
- **Services**: Business logic implementations
  - `GitHubService`: GitHub API interactions
  - `ExcelService`: Report generation
  - `BranchCleanupService`: Main workflow logic
  - `ConfigurationService`: Configuration management
- **Configuration**: Strongly-typed configuration classes
- **Program**: Application entry point and orchestration

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. Feel free to use, modify, and distribute according to your needs.

## Security Considerations

- Never commit Personal Access Tokens to version control
- Use environment variables or secure configuration management for production deployments
- Regularly rotate your Personal Access Tokens
- Review the generated Excel reports before confirming any deletions

## Support

For issues, questions, or feature requests, please create an issue in the repository or contact the development team.
