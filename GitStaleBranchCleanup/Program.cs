using GitStaleBranchCleanup.Services;
using GitStaleBranchCleanup.Configuration;

namespace GitStaleBranchCleanup
{
    class Program
    {
        static async Task Main(string[] args)
        {
            Console.WriteLine("=== Git Stale Branch Cleanup Tool ===\n");

            try
            {
                // Load configuration
                var configService = new ConfigurationService();
                var settings = configService.LoadConfiguration();

                if (!configService.ValidateConfiguration(settings))
                {
                    Console.WriteLine("\nPlease update the appsettings.json file with correct values and try again.");
                    return;
                }

                Console.WriteLine($"Repository: {settings.GitConfig.Owner}/{settings.GitConfig.Repository}");
                Console.WriteLine($"Days threshold: {settings.CleanupConfig.DaysThreshold}");
                Console.WriteLine($"Deletion limit per run: {settings.CleanupConfig.DeletionLimitPerRun}");
                Console.WriteLine($"Exclude patterns: {string.Join(", ", settings.CleanupConfig.ExcludePatterns)}");
                Console.WriteLine();

                // Initialize services
                var gitHubService = new GitHubService(settings.GitConfig);
                var excelService = new ExcelService();
                var branchCleanupService = new BranchCleanupService(
                    gitHubService, 
                    excelService, 
                    settings.CleanupConfig);

                // Analyze branches
                var branches = await branchCleanupService.AnalyzeBranchesAsync();

                var staleBranches = branches.Where(b => b.IsStale).ToList();
                
                if (!staleBranches.Any())
                {
                    Console.WriteLine("\nNo stale branches found. Nothing to clean up!");
                    return;
                }

                Console.WriteLine($"\nAnalysis complete. Check '{settings.CleanupConfig.OutputExcelFile}' for detailed report.");
                
                // Ask user if they want to proceed with deletion
                Console.Write("\nDo you want to proceed with branch deletion? (y/N): ");
                var response = Console.ReadLine()?.Trim().ToLower();
                
                if (response == "y" || response == "yes")
                {
                    await branchCleanupService.DeleteStaleBranchesAsync(branches);
                }
                else
                {
                    Console.WriteLine("Branch deletion skipped. You can review the Excel report and run the tool again.");
                }

                Console.WriteLine("\nTool execution completed.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"An error occurred: {ex.Message}");
                Console.WriteLine("\nPlease check your configuration and try again.");
                
                if (args.Contains("--debug"))
                {
                    Console.WriteLine($"\nFull error details:\n{ex}");
                }
            }

            Console.WriteLine("\nPress any key to exit...");
            Console.ReadKey();
        }
    }
}
