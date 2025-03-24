# Azure Infrastructure-as-Code Deployment Script
# Preconfigured with QDM initials - Automatic authentication

# Set fixed values
$InitialsPrefix = "QDM"
$InitialsPrefixLower = $InitialsPrefix.ToLower() # Lowercase version for container names
$ResourceGroupName = "rg-$InitialsPrefix-flask-crud"
$Location = "westeurope"
$acrName = "acr${InitialsPrefix}crud".ToLower() # Force lowercase for ACR name

# Check if already logged in, if not try to use default credentials
Write-Host "Checking Azure authentication status..." -ForegroundColor Cyan
$loginStatus = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in, attempting automatic login..." -ForegroundColor Yellow
    az login --use-device-code
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Automatic login failed. Please run 'az login' manually before running this script." -ForegroundColor Red
        exit 1
    }
}

# Use the first subscription by default (or current if already selected)
$subscriptionInfo = az account show | ConvertFrom-Json
Write-Host "Using subscription: $($subscriptionInfo.name) ($($subscriptionInfo.id))" -ForegroundColor Green

# Create resource group
Write-Host "Creating resource group: $ResourceGroupName in $Location" -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location

# Create ACR
Write-Host "Creating Azure Container Registry..." -ForegroundColor Cyan
az acr create --resource-group $ResourceGroupName --name $acrName --sku Basic --admin-enabled true

# Get ACR credentials
$acrPassword = $(az acr credential show --name $acrName --query "passwords[0].value" -o tsv)
$acrLoginServer = $(az acr show --name $acrName --query loginServer -o tsv)

# Build and push the container image
Write-Host "Building Docker image for Flask CRUD app..." -ForegroundColor Cyan
docker build -t $acrLoginServer/flask-crud-app:latest .

Write-Host "Logging in to Azure Container Registry..." -ForegroundColor Cyan
az acr login --name $acrName

Write-Host "Pushing the container image to ACR..." -ForegroundColor Cyan
docker push $acrLoginServer/flask-crud-app:latest

# Create container instance with public IP (no VNet integration)
Write-Host "Creating container instance..." -ForegroundColor Cyan
$containerGroupName = "aci-$InitialsPrefixLower-flask-crud"

# Fix for PowerShell multiline command
$containerCreateCmd = "az container create " + `
  "--resource-group $ResourceGroupName " + `
  "--name $containerGroupName " + `
  "--image $acrLoginServer/flask-crud-app:latest " + `
  "--registry-login-server $acrLoginServer " + `
  "--registry-username $acrName " + `
  "--registry-password $acrPassword " + `
  "--ports 80 " + `
  "--dns-name-label ""flask-crud-$InitialsPrefixLower"" " + `
  "--environment-variables FLASK_APP=crudapp.py PYTHONUNBUFFERED=1 " + `
  "--restart-policy OnFailure " + `
  "--cpu 1 " + `
  "--memory 1 " + `
  "--os-type Linux"
  
Invoke-Expression $containerCreateCmd

# Get container IP
$containerIP = $(az container show --resource-group $ResourceGroupName --name $containerGroupName --query ipAddress.ip -o tsv)
$containerFQDN = $(az container show --resource-group $ResourceGroupName --name $containerGroupName --query ipAddress.fqdn -o tsv)

# Output information
Write-Host "`nDeployment complete!" -ForegroundColor Green
Write-Host "Your Flask CRUD application is available at: http://$containerFQDN" -ForegroundColor Green
if ($containerIP) {
  Write-Host "Direct IP access: http://$containerIP" -ForegroundColor Green
}
Write-Host "`nTo view container logs, run:" -ForegroundColor Green
Write-Host "az container logs --resource-group $ResourceGroupName --name $containerGroupName" -ForegroundColor Yellow

Write-Host "`nRemember to delete all resources after showing your assignment to save Azure credits!" -ForegroundColor Yellow
Write-Host "Run: az group delete --name $ResourceGroupName --yes --no-wait" -ForegroundColor Yellow 