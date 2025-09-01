namespace GitStaleBranchCleanup.Models
{
    public class BranchInfo
    {
        public string BranchName { get; set; } = string.Empty;
        public string BranchUrl { get; set; } = string.Empty;
        public DateTime LastCommitDate { get; set; }
        public bool HasActivePullRequest { get; set; }
        public bool IsStale { get; set; }
        public string LastCommitSha { get; set; } = string.Empty;
        public string LastCommitAuthor { get; set; } = string.Empty;
    }
}
