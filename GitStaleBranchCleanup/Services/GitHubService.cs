using Octokit;
using GitStaleBranchCleanup.Models;
using GitStaleBranchCleanup.Configuration;

namespace GitStaleBranchCleanup.Services
{
    public interface IGitHubService
    {
        Task<List<BranchInfo>> GetAllBranchesAsync();
        Task<bool> DeleteBranchAsync(string branchName);
        Task<bool> HasActivePullRequestAsync(string branchName);
    }

    public class GitHubService : IGitHubService
    {
        private readonly GitHubClient _client;
        private readonly GitConfig _gitConfig;

        public GitHubService(GitConfig gitConfig)
        {
            _gitConfig = gitConfig;
            _client = new GitHubClient(new ProductHeaderValue("GitStaleBranchCleanup"));
            
            if (!string.IsNullOrEmpty(_gitConfig.PersonalAccessToken))
            {
                _client.Credentials = new Credentials(_gitConfig.PersonalAccessToken);
            }
        }

        public async Task<List<BranchInfo>> GetAllBranchesAsync()
        {
            try
            {
                Console.WriteLine($"Fetching branches from {_gitConfig.Owner}/{_gitConfig.Repository}...");
                
                var branches = await _client.Repository.Branch.GetAll(_gitConfig.Owner, _gitConfig.Repository);
                var branchInfos = new List<BranchInfo>();

                foreach (var branch in branches)
                {
                    if (branch.Protected)
                    {
                        Console.WriteLine($"Skipping protected branch: {branch.Name}");
                        continue;
                    }

                    var branchInfo = new BranchInfo
                    {
                        BranchName = branch.Name,
                        BranchUrl = $"https://github.com/{_gitConfig.Owner}/{_gitConfig.Repository}/tree/{branch.Name}",
                        LastCommitSha = branch.Commit.Sha
                    };

                    // Get detailed commit information to access the date
                    try
                    {
                        var commit = await _client.Git.Commit.Get(_gitConfig.Owner, _gitConfig.Repository, branch.Commit.Sha);
                        branchInfo.LastCommitDate = commit.Author.Date.DateTime;
                        branchInfo.LastCommitAuthor = commit.Author.Name;
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Warning: Could not get commit details for {branch.Name}: {ex.Message}");
                        branchInfo.LastCommitDate = DateTime.MinValue;
                        branchInfo.LastCommitAuthor = "Unknown";
                    }

                    // Check for active pull requests
                    branchInfo.HasActivePullRequest = await HasActivePullRequestAsync(branch.Name);

                    branchInfos.Add(branchInfo);
                }

                Console.WriteLine($"Found {branchInfos.Count} non-protected branches.");
                return branchInfos;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error fetching branches: {ex.Message}");
                throw;
            }
        }

        public async Task<bool> HasActivePullRequestAsync(string branchName)
        {
            try
            {
                var pullRequests = await _client.PullRequest.GetAllForRepository(
                    _gitConfig.Owner, 
                    _gitConfig.Repository, 
                    new PullRequestRequest 
                    { 
                        State = ItemStateFilter.Open,
                        Head = $"{_gitConfig.Owner}:{branchName}"
                    });

                return pullRequests.Any();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error checking pull requests for branch {branchName}: {ex.Message}");
                return false;
            }
        }

        public async Task<bool> DeleteBranchAsync(string branchName)
        {
            try
            {
                await _client.Git.Reference.Delete(_gitConfig.Owner, _gitConfig.Repository, $"heads/{branchName}");
                Console.WriteLine($"Successfully deleted branch: {branchName}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error deleting branch {branchName}: {ex.Message}");
                return false;
            }
        }
    }
}
