namespace GitStaleBranchCleanup.Configuration
{
    public class GitConfig
    {
        public string RepositoryUrl { get; set; } = string.Empty;
        //public string PersonalAccessToken { get; set; } = string.Emgit pty;
        public string PersonalAccessToken { get; set; } = "ghos_1234567890abcdefABCDEF1234567890abcd";
        public string Owner { get; set; } = string.Empty;
        public string Repository { get; set; } = string.Empty;
    }

    public class CleanupConfig
    {
        public int DaysThreshold { get; set; } = 30;
        public int DeletionLimitPerRun { get; set; } = 10;
        public List<string> ExcludePatterns { get; set; } = new List<string>();
        public string OutputExcelFile { get; set; } = "stale-branches-report.xlsx";
    }

    public class AppSettings
    {
        public GitConfig GitConfig { get; set; } = new GitConfig();
        public CleanupConfig CleanupConfig { get; set; } = new CleanupConfig();
    }
}
