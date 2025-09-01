#!/usr/bin/env pwsh

Write-Host "=== Git Stale Branch Cleanup Tool ===" -ForegroundColor Green
Write-Host ""
Write-Host "Make sure you have configured appsettings.json before running this tool." -ForegroundColor Yellow
Write-Host ""

# Check if appsettings.json exists
if (-not (Test-Path "appsettings.json")) {
    Write-Host "ERROR: appsettings.json not found!" -ForegroundColor Red
    Write-Host "Please copy appsettings.sample.json to appsettings.json and configure it." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if the file contains placeholder values
$config = Get-Content "appsettings.json" -Raw
if ($config -like "*YOUR_GITHUB_PAT_TOKEN_HERE*" -or $config -like "*OWNER*" -or $config -like "*REPOSITORY*") {
    Write-Host "WARNING: appsettings.json appears to contain placeholder values!" -ForegroundColor Red
    Write-Host "Please update the configuration with your actual repository details." -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Do you want to continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

Write-Host ""
Read-Host "Press Enter to start the application"
Write-Host ""
Write-Host "Starting the application..." -ForegroundColor Green
Write-Host ""

# Run the application
dotnet run

Write-Host ""
Write-Host "Application finished." -ForegroundColor Green
Read-Host "Press Enter to exit"
