# Azure Infrastructure-as-Code Deployment Script
# Fully automated deployment with zero user interaction

# Set fixed values
$InitialsPrefix = "QDM"
$InitialsPrefixLower = $InitialsPrefix.ToLower() # Lowercase version for container names
$ResourceGroupName = "rg-$InitialsPrefix-flask-crud"
$Location = "westeurope"
$acrName = "acr${InitialsPrefix}crud".ToLower() # Force lowercase for ACR name
$containerGroupName = "aci-$InitialsPrefixLower-flask-crud"
$vnetName = "vnet-$InitialsPrefix-crud"
$subnetName = "subnet-$InitialsPrefix-aci"
$logAnalyticsName = "la-$InitialsPrefix-crud"
$nsgName = "$subnetName-nsg"
$spName = "sp-azure-iac-$InitialsPrefixLower"

# Function to check if Docker is installed and running
function Test-Docker {
    try {
        $dockerStatus = docker info 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Docker is installed but not running. Will use ACR Tasks instead." -ForegroundColor Yellow
            return $false
        }
        Write-Host "Docker is available and running." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Docker is not installed or not in PATH. Will use ACR Tasks instead." -ForegroundColor Yellow
        return $false
    }
}

# Function to silently create a service principal for automated deployments
function Create-ServicePrincipal-Silent {
    Write-Host "Creating service principal: $spName for automated deployment..." -ForegroundColor Cyan
    
    # Check if the Azure CLI is logged in already
    $loginCheck = az account show 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Azure CLI is not logged in. Cannot create service principal." -ForegroundColor Red
        return $null
    }
    
    # Create the service principal
    $sp = az ad sp create-for-rbac --name $spName --role Contributor --scopes /subscriptions/$(az account show --query id -o tsv) --sdk-auth 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create service principal. Error: $sp" -ForegroundColor Red
        return $null
    }
    
    try {
        $spObj = $sp | ConvertFrom-Json
        
        # Save credentials to file for future use
        $sp | Out-File -FilePath "sp-credentials.json"
        Write-Host "Service principal created and saved to sp-credentials.json" -ForegroundColor Green
        
        return $spObj
    }
    catch {
        Write-Host "Error processing service principal information: $_" -ForegroundColor Red
        return $null
    }
}

# Function to handle Azure authentication - NO USER INTERACTION
function Connect-Azure-Silent {
    # Try environment variables first (for CI/CD or pre-configured environments)
    $envClientId = $env:AZURE_CLIENT_ID
    $envClientSecret = $env:AZURE_CLIENT_SECRET
    $envTenantId = $env:AZURE_TENANT_ID
    $envSubscriptionId = $env:AZURE_SUBSCRIPTION_ID
    
    # Check if already logged in
    Write-Host "Checking Azure authentication status..." -ForegroundColor Cyan
    $loginStatus = az account show 2>&1
    if ($LASTEXITCODE -eq 0) {
        $subscriptionInfo = $loginStatus | ConvertFrom-Json
        Write-Host "Already logged in to subscription: $($subscriptionInfo.name) ($($subscriptionInfo.id))" -ForegroundColor Green
        return $true
    }
    
    # Try service principal from environment variables
    if ($envClientId -and $envClientSecret -and $envTenantId) {
        Write-Host "Authenticating using environment variables..." -ForegroundColor Yellow
        az login --service-principal -u $envClientId -p $envClientSecret --tenant $envTenantId 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0 -and $envSubscriptionId) {
            az account set --subscription $envSubscriptionId 2>&1 | Out-Null
            Write-Host "Authenticated using environment variables" -ForegroundColor Green
            return $true
        }
    }
    
    # Try service principal from credentials file
    if (Test-Path "sp-credentials.json") {
        Write-Host "Authenticating using stored service principal..." -ForegroundColor Yellow
        try {
            $spCreds = Get-Content -Raw -Path "sp-credentials.json" | ConvertFrom-Json
            az login --service-principal -u $spCreds.clientId -p $spCreds.clientSecret --tenant $spCreds.tenantId 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Authenticated using stored service principal" -ForegroundColor Green
                return $true
            }
        }
        catch {
            Write-Host "Error using stored service principal: $_" -ForegroundColor Yellow
            # Continue to next method
        }
    }
    
    # If we reach here, we need to perform a managed identity login or fail
    Write-Host "Attempting to use managed identity authentication..." -ForegroundColor Yellow
    az login --identity 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Authenticated using managed identity" -ForegroundColor Green
        return $true
    }
    
    Write-Host "All silent authentication methods failed." -ForegroundColor Red
    Write-Host "This script requires either:" -ForegroundColor Red
    Write-Host "  1. A pre-existing login (az login)" -ForegroundColor Red
    Write-Host "  2. Environment variables (AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID)" -ForegroundColor Red
    Write-Host "  3. A saved service principal (sp-credentials.json)" -ForegroundColor Red
    Write-Host "  4. Azure managed identity" -ForegroundColor Red
    
    return $false
}

# Function to create virtual network with subnet and NSG
function Create-Network {
    # Create VNet
    Write-Host "Creating Virtual Network: $vnetName..." -ForegroundColor Cyan
    az network vnet create `
        --resource-group $ResourceGroupName `
        --name $vnetName `
        --address-prefix "10.0.0.0/16" `
        --subnet-name $subnetName `
        --subnet-prefix "10.0.0.0/24" 2>&1 | Out-Null
    
    # Create NSG
    Write-Host "Creating Network Security Group: $nsgName..." -ForegroundColor Cyan
    az network nsg create `
        --resource-group $ResourceGroupName `
        --name $nsgName 2>&1 | Out-Null
    
    # Add NSG rules - Allow HTTP and deny everything else
    Write-Host "Configuring NSG rules..." -ForegroundColor Cyan
    az network nsg rule create `
        --resource-group $ResourceGroupName `
        --nsg-name $nsgName `
        --name "AllowHTTP" `
        --priority 100 `
        --protocol Tcp `
        --destination-port-ranges 80 `
        --access Allow 2>&1 | Out-Null
    
    # Associate NSG with subnet
    Write-Host "Associating NSG with subnet..." -ForegroundColor Cyan
    az network vnet subnet update `
        --resource-group $ResourceGroupName `
        --vnet-name $vnetName `
        --name $subnetName `
        --network-security-group $nsgName `
        --delegations Microsoft.ContainerInstance/containerGroups 2>&1 | Out-Null
    
    # Get subnet ID for later use
    $subnetId = az network vnet subnet show `
        --resource-group $ResourceGroupName `
        --vnet-name $vnetName `
        --name $subnetName `
        --query id -o tsv
    
    return $subnetId
}

# Function to create Log Analytics for monitoring
function Create-LogAnalytics {
    Write-Host "Creating Log Analytics workspace: $logAnalyticsName..." -ForegroundColor Cyan
    az monitor log-analytics workspace create `
        --resource-group $ResourceGroupName `
        --workspace-name $logAnalyticsName `
        --sku PerGB2018 `
        --retention-time 30 2>&1 | Out-Null
    
    # Get workspace ID and key for container insights
    $workspaceId = az monitor log-analytics workspace show `
        --resource-group $ResourceGroupName `
        --workspace-name $logAnalyticsName `
        --query customerId -o tsv
    
    $workspaceKey = az monitor log-analytics workspace get-shared-keys `
        --resource-group $ResourceGroupName `
        --workspace-name $logAnalyticsName `
        --query primarySharedKey -o tsv
    
    return @{
        WorkspaceId = $workspaceId
        WorkspaceKey = $workspaceKey
    }
}

# Function to build and push container image with ACR Tasks (no Docker needed)
function Build-PushWithACR {
    Write-Host "Building and pushing container image using ACR Tasks..." -ForegroundColor Cyan
    az acr build --registry $acrName --resource-group $ResourceGroupName --image flask-crud-app:latest . 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ACR Task build failed." -ForegroundColor Red
        return $false
    }
    
    return $true
}

# Function to build and push container image with local Docker
function Build-PushWithDocker {
    $acrLoginServer = az acr show --name $acrName --query loginServer -o tsv
    
    # Build container image
    Write-Host "Building container image with Docker..." -ForegroundColor Cyan
    docker build -t "$acrLoginServer/flask-crud-app:latest" . 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker build failed. Falling back to ACR Tasks." -ForegroundColor Yellow
        return $false
    }
    
    # Get ACR credentials
    $acrPassword = az acr credential show --name $acrName --query "passwords[0].value" -o tsv
    
    # Docker login - using stdin to avoid password in command line
    Write-Host "Logging in to Azure Container Registry..." -ForegroundColor Cyan
    echo $acrPassword | docker login $acrLoginServer -u $acrName --password-stdin 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker login failed. Falling back to ACR Tasks." -ForegroundColor Yellow
        return $false
    }
    
    # Push container image
    Write-Host "Pushing container image to ACR..." -ForegroundColor Cyan
    docker push "$acrLoginServer/flask-crud-app:latest" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker push failed. Falling back to ACR Tasks." -ForegroundColor Yellow
        return $false
    }
    
    return $true
}

# Function to create and deploy container instance
function Deploy-ContainerInstance {
    param (
        [string]$SubnetId,
        [string]$WorkspaceId,
        [string]$WorkspaceKey
    )
    
    $acrLoginServer = az acr show --name $acrName --query loginServer -o tsv
    $acrPassword = az acr credential show --name $acrName --query "passwords[0].value" -o tsv
    
    Write-Host "Creating container instance with public IP..." -ForegroundColor Cyan
    
    # Create container group with public IP
    az container create `
        --resource-group $ResourceGroupName `
        --name $containerGroupName `
        --image "$acrLoginServer/flask-crud-app:latest" `
        --registry-login-server $acrLoginServer `
        --registry-username $acrName `
        --registry-password $acrPassword `
        --ports 80 `
        --environment-variables FLASK_APP=crudapp.py PYTHONUNBUFFERED=1 `
        --restart-policy OnFailure `
        --cpu 1 `
        --memory 1 `
        --os-type Linux `
        --ip-address Public `
        --dns-name-label "flask-$InitialsPrefixLower-crud" `
        --log-analytics-workspace $WorkspaceId `
        --log-analytics-workspace-key $WorkspaceKey 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Container instance deployment failed." -ForegroundColor Red
        return $null
    }
    
    # Get container IP and FQDN
    $containerIP = az container show `
        --resource-group $ResourceGroupName `
        --name $containerGroupName `
        --query ipAddress.ip -o tsv
    
    $containerFqdn = az container show `
        --resource-group $ResourceGroupName `
        --name $containerGroupName `
        --query ipAddress.fqdn -o tsv
    
    return @{
        IP = $containerIP
        FQDN = $containerFqdn
    }
}

# MAIN SCRIPT EXECUTION - FULLY AUTOMATED, NO USER INTERACTION

# 1. Authentication - Try silent methods only
$authenticated = Connect-Azure-Silent
if (-not $authenticated) {
    # If you've run this script before with interactive auth, create a service principal
    # with that login for future use
    Write-Host "Creating a service principal for future runs..." -ForegroundColor Cyan
    az login --only-show-errors
    if ($LASTEXITCODE -eq 0) {
        $sp = Create-ServicePrincipal-Silent
        if ($sp) {
            Write-Host "Service principal created. Re-running authentication..." -ForegroundColor Green
            $authenticated = Connect-Azure-Silent
        }
    }
    
    if (-not $authenticated) {
        Write-Host "Failed to authenticate. Please run 'az login' manually first, then run this script again." -ForegroundColor Red
        exit 1
    }
}

# 2. Create Resource Group
Write-Host "Creating resource group: $ResourceGroupName in $Location" -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location --only-show-errors | Out-Null

# 3. Create Azure Container Registry
Write-Host "Creating Azure Container Registry (ACR): $acrName..." -ForegroundColor Cyan
az acr create --resource-group $ResourceGroupName --name $acrName --sku Basic --admin-enabled true --only-show-errors | Out-Null

# 4. Create Virtual Network and NSG
$subnetId = Create-Network

# 5. Create Log Analytics for monitoring
$logAnalytics = Create-LogAnalytics

# 6. Build and Push Container Image
# Check if Docker is available and working
$dockerAvailable = Test-Docker

# Use appropriate method to build and push container
$imageBuilt = $false
if ($dockerAvailable) {
    # Try with Docker first
    $imageBuilt = Build-PushWithDocker
}

# If Docker failed or not available, fall back to ACR Tasks
if (-not $imageBuilt) {
    Write-Host "Using ACR Tasks for building the container image..." -ForegroundColor Yellow
    $imageBuilt = Build-PushWithACR
}

if (-not $imageBuilt) {
    Write-Host "Failed to build and push container image using either method." -ForegroundColor Red
    Write-Host "Please verify your Dockerfile and try again." -ForegroundColor Red
    exit 1
}

# 7. Deploy Container Instance
$containerInfo = Deploy-ContainerInstance -SubnetId $subnetId -WorkspaceId $logAnalytics.WorkspaceId -WorkspaceKey $logAnalytics.WorkspaceKey

# 8. Output results
if ($containerInfo) {
    Write-Host "`nDeployment successful!" -ForegroundColor Green
    Write-Host "Your Flask CRUD application is deployed with public IP: $($containerInfo.IP)" -ForegroundColor Green
    Write-Host "You can access your application at: http://$($containerInfo.FQDN)" -ForegroundColor Green
    
    # Log Analytics portal URL
    $portalUrl = "https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.OperationalInsights/workspaces/$logAnalyticsName/Overview"
    Write-Host "View container logs in Log Analytics: $portalUrl" -ForegroundColor Green
    
    # Direct log command
    Write-Host "`nTo view container logs directly, run:" -ForegroundColor Green
    Write-Host "az container logs --resource-group $ResourceGroupName --name $containerGroupName" -ForegroundColor Yellow
    
    # Cleanup reminder
    Write-Host "`nRemember to delete all resources after showing your assignment to save Azure credits!" -ForegroundColor Yellow
    Write-Host "Run: az group delete --name $ResourceGroupName --yes --no-wait" -ForegroundColor Yellow
} else {
    Write-Host "`nDeployment failed. Please check the error messages above." -ForegroundColor Red
} 