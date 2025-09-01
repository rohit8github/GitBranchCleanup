using OfficeOpenXml;
using GitStaleBranchCleanup.Models;
using System.IO;

namespace GitStaleBranchCleanup.Services
{
    public interface IExcelService
    {
        Task GenerateReportAsync(List<BranchInfo> branches, string filePath);
    }

    public class ExcelService : IExcelService
    {
        public async Task GenerateReportAsync(List<BranchInfo> branches, string filePath)
        {
            try
            {
                // Set EPPlus license context
                ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

                using var package = new ExcelPackage();
                var worksheet = package.Workbook.Worksheets.Add("Stale Branches Report");

                // Add headers
                worksheet.Cells[1, 1].Value = "BranchName";
                worksheet.Cells[1, 2].Value = "BranchUrl";
                worksheet.Cells[1, 3].Value = "LastCommitDate";
                worksheet.Cells[1, 4].Value = "ActivePullRequest";
                worksheet.Cells[1, 5].Value = "IsStale";
                worksheet.Cells[1, 6].Value = "LastCommitAuthor";

                // Style headers
                using (var range = worksheet.Cells[1, 1, 1, 6])
                {
                    range.Style.Font.Bold = true;
                    range.Style.Fill.PatternType = OfficeOpenXml.Style.ExcelFillStyle.Solid;
                    range.Style.Fill.BackgroundColor.SetColor(System.Drawing.Color.LightGray);
                }

                // Add data
                for (int i = 0; i < branches.Count; i++)
                {
                    var branch = branches[i];
                    int row = i + 2;

                    worksheet.Cells[row, 1].Value = branch.BranchName;
                    worksheet.Cells[row, 2].Value = branch.BranchUrl;
                    worksheet.Cells[row, 3].Value = branch.LastCommitDate.ToString("yyyy-MM-dd HH:mm:ss");
                    worksheet.Cells[row, 4].Value = branch.HasActivePullRequest ? "Yes" : "No";
                    worksheet.Cells[row, 5].Value = branch.IsStale ? "Yes" : "No";
                    worksheet.Cells[row, 6].Value = branch.LastCommitAuthor;

                    // Highlight stale branches
                    if (branch.IsStale)
                    {
                        using (var range = worksheet.Cells[row, 1, row, 6])
                        {
                            range.Style.Fill.PatternType = OfficeOpenXml.Style.ExcelFillStyle.Solid;
                            range.Style.Fill.BackgroundColor.SetColor(System.Drawing.Color.LightYellow);
                        }
                    }
                }

                // Auto-fit columns
                worksheet.Cells.AutoFitColumns();

                // Save file
                var fileInfo = new FileInfo(filePath);
                await package.SaveAsAsync(fileInfo);

                Console.WriteLine($"Excel report generated: {filePath}");
                Console.WriteLine($"Total branches: {branches.Count}");
                Console.WriteLine($"Stale branches: {branches.Count(b => b.IsStale)}");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error generating Excel report: {ex.Message}");
                throw;
            }
        }
    }
}
