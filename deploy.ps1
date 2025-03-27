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
$flaskCrudRepoUrl = "https://github.com/gurkanakdeniz/example-flask-crud.git"
$flaskCrudDir = "example-flask-crud"

# Function to check and clone the Flask CRUD app if needed
function Ensure-FlaskCrudApp {
    Write-Host "Checking for Flask CRUD application..." -ForegroundColor Cyan
    
    # Check if we're already in the Flask CRUD app directory 
    # (look for app.py or crudapp.py or similar Flask files)
    $flaskFiles = @("app.py", "crudapp.py", "static", "templates", "requirements.txt")
    $flaskFound = $false
    
    foreach ($file in $flaskFiles) {
        if (Test-Path $file) {
            $flaskFound = $true
            Write-Host "Found Flask application files in current directory." -ForegroundColor Green
            break
        }
    }
    
    # Check if the Flask CRUD directory exists
    if (-not $flaskFound -and (Test-Path $flaskCrudDir)) {
        # Check if there's a Dockerfile in the root that we should copy
        $rootDockerfile = (Get-Location).Path + "\Dockerfile"
        $hasRootDockerfile = Test-Path $rootDockerfile
        
        # Change to the Flask CRUD directory
        Write-Host "Found Flask CRUD directory, switching to it..." -ForegroundColor Yellow
        Set-Location $flaskCrudDir
        
        # Copy Dockerfile if it exists in the root
        if ($hasRootDockerfile) {
            Write-Host "Copying Dockerfile from root to Flask CRUD directory..." -ForegroundColor Yellow
            Copy-Item -Path $rootDockerfile -Destination "Dockerfile" -Force
        }
        
        $flaskFound = $true
    }
    
    # If Flask CRUD app is not found, clone it
    if (-not $flaskFound) {
        Write-Host "Flask application not found locally. Cloning from GitHub..." -ForegroundColor Yellow
        
        # Save current location to return to
        $originalLocation = Get-Location
        
        # Check if git is available
        try {
            $gitVersion = git --version
            
            # Clone the repository
            Write-Host "Cloning $flaskCrudRepoUrl..." -ForegroundColor Cyan
            git clone $flaskCrudRepoUrl 2>&1 | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Failed to clone Flask CRUD repository." -ForegroundColor Red
                return $false
            }
            
            # Check if there's a Dockerfile in the root that we should copy
            $rootDockerfile = "$originalLocation\Dockerfile"
            $hasRootDockerfile = Test-Path $rootDockerfile
            
            # Change to the cloned directory
            Write-Host "Switching to $flaskCrudDir..." -ForegroundColor Cyan
            Set-Location $flaskCrudDir
            
            # Copy Dockerfile if it exists in the root
            if ($hasRootDockerfile) {
                Write-Host "Copying Dockerfile from root to Flask CRUD directory..." -ForegroundColor Yellow
                Copy-Item -Path $rootDockerfile -Destination "Dockerfile" -Force
            }
            
            return $true
        }
        catch {
            Write-Host "Git is not available. Cannot clone Flask CRUD repository." -ForegroundColor Red
            Write-Host "Please install Git or manually clone $flaskCrudRepoUrl" -ForegroundColor Red
            return $false
        }
    }
    
    return $true
}

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
    
    # Check if Dockerfile exists
    if (-not (Test-Path "Dockerfile")) {
        # Try to find or create one
        Write-Host "Dockerfile not found in current directory." -ForegroundColor Yellow
        
        # Create a simple Dockerfile if one doesn't exist
        Write-Host "Creating a basic Dockerfile for Flask application..." -ForegroundColor Yellow
        
        @"
FROM python:3.9-slim

WORKDIR /app

COPY . /app/

RUN pip install --no-cache-dir -r requirements.txt

ENV FLASK_APP=crudapp.py
ENV PYTHONUNBUFFERED=1
ENV FLASK_ENV=production

EXPOSE 80

CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=80"]
"@ | Out-File -FilePath "Dockerfile" -Encoding utf8

        # Give some time for the file to be written
        Start-Sleep -Seconds 1
    }
    
    # Ensure we're using the absolute path for the context
    $currentDir = Get-Location
    
    # Log the command for debugging
    $buildCommand = "az acr build --registry $acrName --resource-group $ResourceGroupName --image flask-crud-app:latest '$currentDir'"
    Write-Host "Running: $buildCommand" -ForegroundColor Yellow
    
    # Run ACR build with the current directory context
    az acr build --registry $acrName --resource-group $ResourceGroupName --image flask-crud-app:latest "$currentDir" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ACR Task build failed. Trying with more verbose output for debugging..." -ForegroundColor Red
        # Try again with output displayed
        az acr build --registry $acrName --resource-group $ResourceGroupName --image flask-crud-app:latest "$currentDir"
        return $false
    }
    
    return $true
}

# Function to import a pre-built image (fallback when Docker and ACR Tasks are unavailable)
function Import-PrebuiltImage {
    Write-Host "Using fallback method: importing a pre-built Flask image..." -ForegroundColor Yellow
    
    # Import a compatible public image for Flask
    $sourceImage = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
    Write-Host "Importing $sourceImage to your ACR..." -ForegroundColor Cyan
    
    az acr import --name $acrName --source $sourceImage --image flask-crud-app:latest 2>&1 | Out-Null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to import pre-built image. Trying a different public image..." -ForegroundColor Yellow
        
        # Try a different image as fallback
        $sourceImage = "docker.io/tiangolo/uwsgi-nginx-flask:python3.8"
        Write-Host "Importing $sourceImage to your ACR..." -ForegroundColor Cyan
        
        az acr import --name $acrName --source $sourceImage --image flask-crud-app:latest 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to import any pre-built images." -ForegroundColor Red
            return $false
        }
    }
    
    Write-Host "Successfully imported pre-built image to your ACR." -ForegroundColor Green
    return $true
}

# Function to build and push container image with local Docker
function Build-PushWithDocker {
    $acrLoginServer = az acr show --name $acrName --query loginServer -o tsv
    
    # Build container image
    Write-Host "Building container image with Docker..." -ForegroundColor Cyan
    
    # Show the Dockerfile content for debugging
    Write-Host "Using Dockerfile content:" -ForegroundColor Yellow
    Get-Content -Path "Dockerfile" | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
    # Build with verbose output
    Write-Host "Running docker build -t $acrLoginServer/flask-crud-app:latest ." -ForegroundColor Yellow
    docker build -t "$acrLoginServer/flask-crud-app:latest" .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker build failed." -ForegroundColor Red
        return $false
    }
    
    # Get ACR credentials
    $acrPassword = az acr credential show --name $acrName --query "passwords[0].value" -o tsv
    
    # Force re-login to ACR - bypass the existing credentials check
    Write-Host "Logging in to Azure Container Registry..." -ForegroundColor Cyan
    echo $acrPassword | docker login $acrLoginServer -u $acrName --password-stdin
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker login failed." -ForegroundColor Red
        return $false
    }
    
    # Push container image with verbose output
    Write-Host "Pushing container image to ACR..." -ForegroundColor Cyan
    Write-Host "Running docker push $acrLoginServer/flask-crud-app:latest" -ForegroundColor Yellow
    docker push "$acrLoginServer/flask-crud-app:latest"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker push failed. Error code: $LASTEXITCODE" -ForegroundColor Red
        
        # Check if the image exists locally
        Write-Host "Checking if image exists locally..." -ForegroundColor Yellow
        docker image ls | findstr "$acrLoginServer/flask-crud-app"
        
        # Check if we can reach the ACR
        Write-Host "Testing connectivity to ACR..." -ForegroundColor Yellow
        Test-NetConnection -ComputerName "$acrLoginServer" -Port 443
        
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
    
    # Base command parameters - common to all deployment types
    $commonParams = @(
        "--resource-group $ResourceGroupName",
        "--name $containerGroupName",
        "--image ""$acrLoginServer/flask-crud-app:latest""",
        "--registry-login-server $acrLoginServer",
        "--registry-username $acrName",
        "--registry-password $acrPassword",
        "--ports 80",
        "--restart-policy OnFailure",
        "--cpu 1",
        "--memory 1",
        "--os-type Linux",
        "--ip-address Public",
        "--dns-name-label ""flask-$InitialsPrefixLower-crud""",
        "--log-analytics-workspace $WorkspaceId",
        "--log-analytics-workspace-key $WorkspaceKey"
    )
    
    # Create container instance command
    $command = "az container create " + ($commonParams -join " ") + " --environment-variables FLASK_APP=crudapp.py PYTHONUNBUFFERED=1"
    
    Write-Host "Running container deployment command..." -ForegroundColor Yellow
    Write-Host $command -ForegroundColor Gray
    
    # Execute the command to create container instance
    Invoke-Expression $command 2>&1 | Out-Null
    
    # If it fails, try again without the environment variables (for pre-built images)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Initial deployment failed, trying alternative configuration for pre-built images..." -ForegroundColor Yellow
        $command = "az container create " + ($commonParams -join " ")
        Write-Host $command -ForegroundColor Gray
        Invoke-Expression $command 2>&1 | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Container instance deployment failed." -ForegroundColor Red
            return $null
        }
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

# Ensure current user has proper permissions on ACR
Write-Host "Assigning AcrPush role to ensure push permissions..." -ForegroundColor Yellow
$currentUser = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee $currentUser --role AcrPush --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.ContainerRegistry/registries/$acrName --only-show-errors | Out-Null

# 4. Create Virtual Network and NSG
$subnetId = Create-Network

# 5. Create Log Analytics for monitoring
$logAnalytics = Create-LogAnalytics

# 6. Ensure Flask CRUD application is available
$flaskReady = Ensure-FlaskCrudApp
if (-not $flaskReady) {
    Write-Host "Failed to set up Flask CRUD application. Cannot continue." -ForegroundColor Red
    exit 1
}

# 7. Build and Push Container Image
# Check if Docker is available and working
$dockerAvailable = Test-Docker

# Use appropriate method to build and push container
$imageBuilt = $false
if ($dockerAvailable) {
    # Try with Docker first
    $imageBuilt = Build-PushWithDocker
}

# If Docker failed, exit with error
if (-not $imageBuilt) {
    Write-Host "Failed to build and push container image using Docker." -ForegroundColor Red
    Write-Host "Please verify your Docker installation and network connectivity to ACR." -ForegroundColor Red
    Write-Host "You can try manually building and pushing the image with these commands:" -ForegroundColor Yellow
    $acrLoginServer = az acr show --name $acrName --query loginServer -o tsv
    Write-Host "  docker build -t $acrLoginServer/flask-crud-app:latest ." -ForegroundColor Yellow
    Write-Host "  docker login $acrLoginServer -u $acrName" -ForegroundColor Yellow
    Write-Host "  docker push $acrLoginServer/flask-crud-app:latest" -ForegroundColor Yellow
    exit 1
}

# 8. Deploy Container Instance
$containerInfo = Deploy-ContainerInstance -SubnetId $subnetId -WorkspaceId $logAnalytics.WorkspaceId -WorkspaceKey $logAnalytics.WorkspaceKey

# 9. Output results
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