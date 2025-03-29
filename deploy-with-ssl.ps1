# Azure Infrastructure-as-Code Deployment Script with SSL certificate
# This script deploys the infrastructure with HTTPS enabled

param (
    [Parameter(Mandatory = $true)]
    [string]$SslCertPath,
    
    [Parameter(Mandatory = $true)]
    [string]$SslCertPassword,
    
    [Parameter(Mandatory = $false)]
    [string]$HttpsHostName = "iac.quinten-de-meyer.be",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseCredentialsFile
)

# Call the main deployment script with SSL parameters
$deployParams = @{
    SslCertPath = $SslCertPath
    SslCertPassword = $SslCertPassword
    HttpsHostName = $HttpsHostName
}

if ($UseCredentialsFile) {
    $deployParams.Add("UseCredentialsFile", $true)
}

Write-Host "Starting deployment with SSL certificate..." -ForegroundColor Cyan

# Execute the main deployment script with SSL parameters
try {
    & .\deploy.ps1 @deployParams
} catch {
    Write-Error "An error occurred during deployment: $_"
    exit 1
}

Write-Host "IMPORTANT: Remember to clean up resources after demonstration to save Azure credits" -ForegroundColor Yellow
Write-Host "Run the following command to delete all resources:" -ForegroundColor Yellow
Write-Host "az group delete --name rg-qdm-flask-crud --yes" -ForegroundColor Yellow 