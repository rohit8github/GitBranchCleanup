using Microsoft.Extensions.Configuration;
using GitStaleBranchCleanup.Configuration;
using Newtonsoft.Json;

namespace GitStaleBranchCleanup.Services
{
    public interface IConfigurationService
    {
        AppSettings LoadConfiguration();
        void SaveConfiguration(AppSettings settings);
        bool ValidateConfiguration(AppSettings settings);
    }

    public class ConfigurationService : IConfigurationService
    {
        private const string ConfigFileName = "appsettings.json";

        public AppSettings LoadConfiguration()
        {
            try
            {
                var configuration = new ConfigurationBuilder()
                    .SetBasePath(Directory.GetCurrentDirectory())
                    .AddJsonFile(ConfigFileName, optional: false, reloadOnChange: true)
                    .Build();

                var settings = new AppSettings();
                configuration.Bind(settings);

                return settings;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error loading configuration: {ex.Message}");
                throw;
            }
        }

        public void SaveConfiguration(AppSettings settings)
        {
            try
            {
                var json = JsonConvert.SerializeObject(settings, Formatting.Indented);
                File.WriteAllText(ConfigFileName, json);
                Console.WriteLine($"Configuration saved to {ConfigFileName}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error saving configuration: {ex.Message}");
                throw;
            }
        }

        public bool ValidateConfiguration(AppSettings settings)
        {
            var errors = new List<string>();

            if (string.IsNullOrWhiteSpace(settings.GitConfig.Owner))
                errors.Add("Git Owner is required");

            if (string.IsNullOrWhiteSpace(settings.GitConfig.Repository))
                errors.Add("Git Repository is required");

            if (string.IsNullOrWhiteSpace(settings.GitConfig.PersonalAccessToken))
                errors.Add("Personal Access Token is required");

            if (settings.CleanupConfig.DaysThreshold <= 0)
                errors.Add("Days threshold must be greater than 0");

            if (settings.CleanupConfig.DeletionLimitPerRun <= 0)
                errors.Add("Deletion limit per run must be greater than 0");

            if (errors.Any())
            {
                Console.WriteLine("Configuration validation failed:");
                foreach (var error in errors)
                {
                    Console.WriteLine($"  - {error}");
                }
                return false;
            }

            return true;
        }
    }
}
