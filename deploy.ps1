# Azure Infrastructure-as-Code Deployment Script
# Assignment 2: Deploying Flask CRUD App to Azure Container Instances

# Parameters
param (
    [Parameter(Mandatory = $false)]
    [string]$InitialsPrefix = "YOUR",

    [Parameter(Mandatory = $false)]
    [string]$Location = "westeurope",

    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "bicep/main.parameters.json",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "",
    
    [Parameter(Mandatory = $false)]
    [string]$AcrSuffix = "01"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Check if parameters file exists and read InitialsPrefix from it
if (Test-Path $ParametersFile) {
    try {
        $params = Get-Content -Raw -Path $ParametersFile | ConvertFrom-Json
        if ($params.parameters.initials -and $params.parameters.initials.value -ne "YOUR") {
            $InitialsPrefix = $params.parameters.initials.value
            Write-Host "Using initials from parameters file: $InitialsPrefix" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "Could not read initials from parameters file, using default: $InitialsPrefix" -ForegroundColor Yellow
    }
}

# Set resource group name if not provided
if ([string]::IsNullOrEmpty($ResourceGroupName)) {
    $ResourceGroupName = "rg-$InitialsPrefix-flask-crud"
}

# Create the resource group
function New-ResourceGroup {
    Write-Host "Creating Resource Group: $ResourceGroupName" -ForegroundColor Cyan
    az group create --name $ResourceGroupName --location $Location
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create resource group"
        exit 1
    }
}

# Import the Flask CRUD app repository
function Import-FlaskCrudRepo {
    $repoUrl = "https://github.com/gurkanakdeniz/example-flask-crud.git"
    $repoDir = "example-flask-crud"

    if (Test-Path $repoDir) {
        Write-Host "Flask CRUD repository already exists locally" -ForegroundColor Green
        return
    }

    Write-Host "Cloning Flask CRUD repository..." -ForegroundColor Cyan
    git clone $repoUrl
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to clone repository"
        exit 1
    }
}

# Build and push the container image
function New-ContainerImage {
    # ACR name must be lowercase and globally unique
    $acrName = "acr$($InitialsPrefix.ToLower())crud$AcrSuffix"
    Write-Host "Using ACR name: $acrName" -ForegroundColor Cyan
    
    $imageName = "flask-crud"
    $imageTag = "latest"

    # Deploy ACR using Bicep
    Write-Host "Deploying Azure Container Registry..." -ForegroundColor Cyan
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file bicep/modules/acr.bicep `
        --parameters acrName=$acrName location=$Location
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy ACR. If the name is already taken, try running the script with a different AcrSuffix: .\deploy.ps1 -AcrSuffix '02'"
        exit 1
    }

    # Get ACR login server
    $acrLoginServer = az acr show --name $acrName --query loginServer -o tsv
    $fullImageName = "$acrLoginServer/$imageName`:$imageTag"

    # Login to ACR
    Write-Host "Logging in to Azure Container Registry..." -ForegroundColor Cyan
    az acr login --name $acrName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to login to ACR"
        exit 1
    }

    # Go to the Flask CRUD repo directory
    Push-Location example-flask-crud

    # Build and tag the Docker image
    Write-Host "Building Docker image..." -ForegroundColor Cyan
    docker build -t $fullImageName .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build Docker image"
        Pop-Location
        exit 1
    }

    # Push the image to ACR
    Write-Host "Pushing Docker image to ACR..." -ForegroundColor Cyan
    docker push $fullImageName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push Docker image to ACR"
        Pop-Location
        exit 1
    }

    Pop-Location

    # Update the parameters file with the image name
    Write-Host "Updating parameters file with image name..." -ForegroundColor Cyan
    $params = Get-Content -Raw -Path $ParametersFile | ConvertFrom-Json
    $params.parameters.containerImageName.value = $fullImageName
    $params | ConvertTo-Json -Depth 10 | Set-Content -Path $ParametersFile

    return @{
        FullImageName = $fullImageName
        AcrName = $acrName
    }
}

# Deploy Azure resources using Bicep
function Start-AzureDeployment {
    param (
        [string]$fullImageName,
        [string]$acrName
    )

    Write-Host "Deploying Azure resources using Bicep..." -ForegroundColor Cyan
    
    # Update parameters file with container image name if not already done
    $params = Get-Content -Raw -Path $ParametersFile | ConvertFrom-Json
    if ([string]::IsNullOrEmpty($params.parameters.containerImageName.value)) {
        $params.parameters.containerImageName.value = $fullImageName
        $params | ConvertTo-Json -Depth 10 | Set-Content -Path $ParametersFile
    }
    
    # Update initials in parameters file
    $params.parameters.initials.value = $InitialsPrefix
    $params | ConvertTo-Json -Depth 10 | Set-Content -Path $ParametersFile

    # Create a named deployment for easier reference
    $deploymentName = "deploy-$InitialsPrefix-$(Get-Date -Format 'yyMMddHHmm')"
    
    # Deploy using the main Bicep template
    Write-Host "Starting deployment with name: $deploymentName" -ForegroundColor Cyan
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file bicep/main.bicep `
        --parameters @$ParametersFile `
        --parameters acrName=$acrName `
        --name $deploymentName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy Azure resources"
        exit 1
    }

    # Get the container IP address
    $containerIp = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query properties.outputs.containerIPv4Address.value -o tsv

    # Get Application Gateway information
    $appGatewayPublicIp = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query properties.outputs.appGatewayPublicIp.value -o tsv

    $appGatewayFqdn = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query properties.outputs.appGatewayFQDN.value -o tsv

    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Your Flask CRUD app has been deployed with a private IP: $containerIp" -ForegroundColor Cyan
    Write-Host "The Application Gateway has been configured to provide public access to your app." -ForegroundColor Green
    Write-Host "You can access the Flask CRUD app publicly at:" -ForegroundColor Green
    Write-Host "  - Public IP: http://$appGatewayPublicIp" -ForegroundColor Cyan
    Write-Host "  - DNS Name: http://$appGatewayFqdn" -ForegroundColor Cyan
}

# Create an ACR token with least privilege access
function New-ACRToken {
    param (
        [string]$acrName
    )
    
    $tokenName = "acrpull-token"
    
    Write-Host "Creating ACR token with pull permissions..." -ForegroundColor Cyan
    
    # Create a scope map for pull access only
    az acr scope-map create `
        --name pull-scope-map `
        --registry $acrName `
        --repository flask-crud content/read
    
    # Create a token with the scope map
    az acr token create `
        --name $tokenName `
        --registry $acrName `
        --scope-map pull-scope-map
    
    Write-Host "Created ACR token with least privilege access" -ForegroundColor Green
}

# Main execution flow
Write-Host "Starting Azure Infrastructure-as-Code deployment for Flask CRUD app" -ForegroundColor Green
Write-Host "Using initials: $InitialsPrefix" -ForegroundColor Green
Write-Host "Using ACR suffix: $AcrSuffix" -ForegroundColor Green

# Check if Azure CLI is installed
try {
    az --version | Out-Null
}
catch {
    Write-Error "Azure CLI is not installed. Please install it before running this script."
    exit 1
}

# Check if Docker is installed
try {
    docker --version | Out-Null
}
catch {
    Write-Error "Docker is not installed. Please install it before running this script."
    exit 1
}

# Check if logged in to Azure
az account show 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Azure. Please run 'az login' first." -ForegroundColor Yellow
    az login
}

# Execute deployment steps
New-ResourceGroup
Import-FlaskCrudRepo
$containerResult = New-ContainerImage
New-ACRToken -acrName $containerResult.AcrName
Start-AzureDeployment -fullImageName $containerResult.FullImageName -acrName $containerResult.AcrName

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "IMPORTANT: Remember to clean up resources after demonstration to save Azure credits" -ForegroundColor Yellow
Write-Host "Run the following command to delete all resources:" -ForegroundColor Yellow
Write-Host "az group delete --name $ResourceGroupName --yes" -ForegroundColor Yellow 