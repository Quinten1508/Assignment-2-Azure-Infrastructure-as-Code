# Script to set Azure credentials as environment variables
# IMPORTANT: Do not commit this file to source control with secrets

# Set environment variables for the current session
$credentialsFile = "./sp-credentials.json"

if (Test-Path $credentialsFile) {
    try {
        $credentials = Get-Content -Raw -Path $credentialsFile | ConvertFrom-Json
        
        # Set environment variables
        $env:AZURE_CLIENT_ID = $credentials.clientId
        $env:AZURE_CLIENT_SECRET = $credentials.clientSecret
        $env:AZURE_SUBSCRIPTION_ID = $credentials.subscriptionId
        $env:AZURE_TENANT_ID = $credentials.tenantId
        
        Write-Host "Azure credentials have been set as environment variables for the current session." -ForegroundColor Green
        Write-Host "Use these environment variables in your scripts instead of hardcoded credentials." -ForegroundColor Green
    } catch {
        Write-Error "Failed to read credentials file: $_"
    }
} else {
    Write-Error "Credentials file not found at $credentialsFile"
}

# Instructions for using these environment variables
Write-Host ""
Write-Host "To use these credentials in your scripts, replace hardcoded values with:" -ForegroundColor Cyan
Write-Host '  $clientId = $env:AZURE_CLIENT_ID' -ForegroundColor Yellow
Write-Host '  $clientSecret = $env:AZURE_CLIENT_SECRET' -ForegroundColor Yellow 
Write-Host '  $subscriptionId = $env:AZURE_SUBSCRIPTION_ID' -ForegroundColor Yellow
Write-Host '  $tenantId = $env:AZURE_TENANT_ID' -ForegroundColor Yellow
Write-Host ""
Write-Host "SECURITY NOTE: Environment variables only last for the current PowerShell session." -ForegroundColor Red 