using GitStaleBranchCleanup.Models;
using GitStaleBranchCleanup.Configuration;
using System.Text.RegularExpressions;

namespace GitStaleBranchCleanup.Services
{
    public interface IBranchCleanupService
    {
        Task<List<BranchInfo>> AnalyzeBranchesAsync();
        Task<bool> DeleteStaleBranchesAsync(List<BranchInfo> staleBranches);
    }

    public class BranchCleanupService : IBranchCleanupService
    {
        private readonly IGitHubService _gitHubService;
        private readonly IExcelService _excelService;
        private readonly CleanupConfig _config;

        public BranchCleanupService(
            IGitHubService gitHubService,
            IExcelService excelService,
            CleanupConfig config)
        {
            _gitHubService = gitHubService;
            _excelService = excelService;
            _config = config;
        }

        public async Task<List<BranchInfo>> AnalyzeBranchesAsync()
        {
            try
            {
                Console.WriteLine("Starting branch analysis...");
                
                // Get all branches
                var allBranches = await _gitHubService.GetAllBranchesAsync();
                
                // Calculate threshold date
                var thresholdDate = DateTime.Now.AddDays(-_config.DaysThreshold);
                Console.WriteLine($"Threshold date: {thresholdDate:yyyy-MM-dd}");

                // Analyze each branch
                foreach (var branch in allBranches)
                {
                    // Check if branch matches exclude patterns
                    bool shouldExclude = _config.ExcludePatterns.Any(pattern => 
                        MatchesPattern(branch.BranchName, pattern));

                    // Determine if branch is stale
                    branch.IsStale = !shouldExclude && 
                                   branch.LastCommitDate < thresholdDate && 
                                   !branch.HasActivePullRequest;

                    if (shouldExclude)
                    {
                        Console.WriteLine($"Excluding branch (pattern match): {branch.BranchName}");
                    }
                    else if (branch.HasActivePullRequest)
                    {
                        Console.WriteLine($"Excluding branch (active PR): {branch.BranchName}");
                    }
                    else if (branch.IsStale)
                    {
                        Console.WriteLine($"Stale branch found: {branch.BranchName} (last commit: {branch.LastCommitDate:yyyy-MM-dd})");
                    }
                }

                // Generate Excel report
                await _excelService.GenerateReportAsync(allBranches, _config.OutputExcelFile);

                return allBranches;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error during branch analysis: {ex.Message}");
                throw;
            }
        }

        public async Task<bool> DeleteStaleBranchesAsync(List<BranchInfo> staleBranches)
        {
            try
            {
                var branchesToDelete = staleBranches
                    .Where(b => b.IsStale)
                    .Take(_config.DeletionLimitPerRun)
                    .ToList();

                if (!branchesToDelete.Any())
                {
                    Console.WriteLine("No stale branches to delete.");
                    return true;
                }

                Console.WriteLine($"\nFound {staleBranches.Count(b => b.IsStale)} stale branches.");
                Console.WriteLine($"Will delete up to {_config.DeletionLimitPerRun} branches in this run.");
                Console.WriteLine("\nBranches to be deleted:");
                
                foreach (var branch in branchesToDelete)
                {
                    Console.WriteLine($"  - {branch.BranchName} (last commit: {branch.LastCommitDate:yyyy-MM-dd})");
                }

                Console.Write("\nDo you want to proceed with deletion? (y/N): ");
                var response = Console.ReadLine()?.Trim().ToLower();
                
                if (response != "y" && response != "yes")
                {
                    Console.WriteLine("Deletion cancelled by user.");
                    return false;
                }

                Console.WriteLine("\nStarting branch deletion...");
                
                int successCount = 0;
                foreach (var branch in branchesToDelete)
                {
                    if (await _gitHubService.DeleteBranchAsync(branch.BranchName))
                    {
                        successCount++;
                    }
                }

                Console.WriteLine($"\nDeletion completed. {successCount}/{branchesToDelete.Count} branches deleted successfully.");
                
                if (staleBranches.Count(b => b.IsStale) > _config.DeletionLimitPerRun)
                {
                    Console.WriteLine($"Note: {staleBranches.Count(b => b.IsStale) - _config.DeletionLimitPerRun} stale branches remain. Run the tool again to delete more.");
                }

                return successCount == branchesToDelete.Count;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error during branch deletion: {ex.Message}");
                throw;
            }
        }

        private bool MatchesPattern(string branchName, string pattern)
        {
            try
            {
                // Handle wildcard patterns
                if (pattern.Contains("*"))
                {
                    // Convert wildcard pattern to regex
                    var regexPattern = "^" + Regex.Escape(pattern).Replace("\\*", ".*") + "$";
                    return Regex.IsMatch(branchName, regexPattern, RegexOptions.IgnoreCase);
                }
                
                // Exact match
                return string.Equals(branchName, pattern, StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                // If regex fails, fall back to exact match
                return string.Equals(branchName, pattern, StringComparison.OrdinalIgnoreCase);
            }
        }
    }
}
