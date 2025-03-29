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
    [string]$AcrSuffix = "01",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseCredentialsFile,
    
    [Parameter(Mandatory = $false)]
    [string]$SslCertPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$SslCertPassword = "",
    
    [Parameter(Mandatory = $false)]
    [string]$HttpsHostName = "iac.quinten-de-meyer.be"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Load environment variables from credentials file if requested
if ($UseCredentialsFile) {
    $credentialsFile = "./sp-credentials.json"
    if (Test-Path $credentialsFile) {
        try {
            Write-Host "Loading credentials from file..." -ForegroundColor Cyan
            $credentials = Get-Content -Raw -Path $credentialsFile | ConvertFrom-Json
            
            # Set environment variables
            $env:AZURE_CLIENT_ID = $credentials.clientId
            $env:AZURE_CLIENT_SECRET = $credentials.clientSecret
            $env:AZURE_SUBSCRIPTION_ID = $credentials.subscriptionId
            $env:AZURE_TENANT_ID = $credentials.tenantId
            
            Write-Host "Credentials loaded successfully" -ForegroundColor Green
        } catch {
            Write-Error "Failed to read credentials file: $_"
            exit 1
        }
    } else {
        Write-Error "Credentials file not found at $credentialsFile"
        exit 1
    }
}

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
    
    # Handle SSL certificate configuration if provided
    $sslParams = @{}
    if (-not [string]::IsNullOrEmpty($SslCertPath) -and (Test-Path $SslCertPath)) {
        Write-Host "Configuring SSL certificate for HTTPS..." -ForegroundColor Cyan
        
        # Convert certificate to base64
        $certBytes = [System.IO.File]::ReadAllBytes($SslCertPath)
        $base64Cert = [System.Convert]::ToBase64String($certBytes)
        
        # Add SSL parameters
        $sslParams = @{
            "enableHttps" = $true
            "sslCertificateData" = $base64Cert
            "sslCertificatePassword" = $SslCertPassword
            "httpsHostName" = $HttpsHostName
        }
        
        Write-Host "SSL certificate configured with hostname: $HttpsHostName" -ForegroundColor Green
    }

    # Create a named deployment for easier reference
    $deploymentName = "deploy-$InitialsPrefix-$(Get-Date -Format 'yyMMddHHmm')"
    
    # Prepare deployment parameters
    $deploymentParams = @($ParametersFile)
    foreach ($key in $sslParams.Keys) {
        if ($key -eq "sslCertificateData") {
            # Use a temporary file for the large certificate data
            $tempFile = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempFile -Value $sslParams[$key]
            $deploymentParams += "$key=@$tempFile"
        } else {
            $deploymentParams += "$key=$($sslParams[$key])"
        }
    }
    
    # Deploy using the main Bicep template
    Write-Host "Starting deployment with name: $deploymentName" -ForegroundColor Cyan
    
    $deployCmd = "az deployment group create --resource-group $ResourceGroupName --template-file bicep/main.bicep --parameters @$ParametersFile --parameters acrName=$acrName"
    
    # Add SSL parameters if provided
    foreach ($key in $sslParams.Keys) {
        if ($key -eq "sslCertificateData") {
            # Skip adding directly to command line due to size
            continue
        } elseif ($key -eq "sslCertificatePassword" -and -not [string]::IsNullOrEmpty($sslParams[$key])) {
            $deployCmd += " --parameters $key=$($sslParams[$key])"
        } elseif ($key -ne "sslCertificatePassword") {
            $deployCmd += " --parameters $key=$($sslParams[$key])"
        }
    }
    
    $deployCmd += " --name $deploymentName"
    
    # If we have certificate data, use a different approach to pass it
    if ($sslParams.ContainsKey("sslCertificateData")) {
        # Create a temporary parameter file with all parameters including the certificate
        $tempParamsFile = [System.IO.Path]::GetTempFileName()
        $allParams = Get-Content -Raw -Path $ParametersFile | ConvertFrom-Json
        
        # Add or update SSL parameters
        if (-not $allParams.parameters.PSObject.Properties["enableHttps"]) {
            $allParams.parameters | Add-Member -NotePropertyName "enableHttps" -NotePropertyValue @{value = $true}
        } else {
            $allParams.parameters.enableHttps.value = $true
        }
        
        if (-not $allParams.parameters.PSObject.Properties["sslCertificateData"]) {
            $allParams.parameters | Add-Member -NotePropertyName "sslCertificateData" -NotePropertyValue @{value = $sslParams["sslCertificateData"]}
        } else {
            $allParams.parameters.sslCertificateData.value = $sslParams["sslCertificateData"]
        }
        
        if (-not [string]::IsNullOrEmpty($SslCertPassword)) {
            if (-not $allParams.parameters.PSObject.Properties["sslCertificatePassword"]) {
                $allParams.parameters | Add-Member -NotePropertyName "sslCertificatePassword" -NotePropertyValue @{value = $SslCertPassword}
            } else {
                $allParams.parameters.sslCertificatePassword.value = $SslCertPassword
            }
        }
        
        if (-not [string]::IsNullOrEmpty($HttpsHostName)) {
            if (-not $allParams.parameters.PSObject.Properties["httpsHostName"]) {
                $allParams.parameters | Add-Member -NotePropertyName "httpsHostName" -NotePropertyValue @{value = $HttpsHostName}
            } else {
                $allParams.parameters.httpsHostName.value = $HttpsHostName
            }
        }
        
        # Write the updated parameters to the temp file
        $allParams | ConvertTo-Json -Depth 10 | Set-Content -Path $tempParamsFile
        
        # Use the temporary file for deployment
        $deployCmd = "az deployment group create --resource-group $ResourceGroupName --template-file bicep/main.bicep --parameters @$tempParamsFile --name $deploymentName"
    }
    
    # Execute the deployment command
    Invoke-Expression $deployCmd
    
    # Clean up any temporary files
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    if (Test-Path $tempParamsFile) { Remove-Item $tempParamsFile -Force }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy Azure resources"
        exit 1
    }
    
    # Get the output values from the deployment
    Write-Host "Retrieving deployment outputs..." -ForegroundColor Cyan
    $outputs = az deployment group show `
        --resource-group $ResourceGroupName `
        --name $deploymentName `
        --query properties.outputs `
        -o json | ConvertFrom-Json
    
    return $outputs
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

# Check if service principal credentials are available as environment variables
function Test-ServicePrincipalCredentials {
    if ([string]::IsNullOrEmpty($env:AZURE_CLIENT_ID) -or
        [string]::IsNullOrEmpty($env:AZURE_CLIENT_SECRET) -or
        [string]::IsNullOrEmpty($env:AZURE_TENANT_ID)) {
        return $false
    }
    return $true
}

# Main execution
try {
    # Check if logged in to Azure
    $loginStatus = az account show --query "user.name" -o tsv 2>$null
    if (-not $loginStatus) {
        Write-Host "Not logged in to Azure. Attempting to log in with service principal..." -ForegroundColor Yellow
        if ($UseCredentialsFile -and (Test-Path "./sp-credentials.json")) {
            $creds = Get-Content -Raw -Path "./sp-credentials.json" | ConvertFrom-Json
            Write-Host "Logging in with service principal..." -ForegroundColor Cyan
            az login --service-principal --username $creds.appId --password $creds.password --tenant $creds.tenant
        } else {
            Write-Host "Logging in to Azure..." -ForegroundColor Cyan
            az login
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to login to Azure"
            exit 1
        }
    } else {
        Write-Host "Already logged in as: $loginStatus" -ForegroundColor Green
    }
    
    # Set the subscription if specified in credentials
    if ($UseCredentialsFile -and (Test-Path "./sp-credentials.json")) {
        $creds = Get-Content -Raw -Path "./sp-credentials.json" | ConvertFrom-Json
        if ($creds.subscriptionId) {
            Write-Host "Setting subscription to: $($creds.subscriptionId)" -ForegroundColor Cyan
            az account set --subscription $creds.subscriptionId
        }
    }
    
    # Check if resource group exists, create if not
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq "false") {
        New-ResourceGroup
    } else {
        Write-Host "Using existing resource group: $ResourceGroupName" -ForegroundColor Green
    }
    
    # Clone the Flask CRUD repository if necessary
    Import-FlaskCrudRepo
    
    # Build and push the container image
    $containerInfo = New-ContainerImage
    
    # Deploy Azure resources using Bicep
    $deploymentOutputs = Start-AzureDeployment -fullImageName $containerInfo.FullImageName -acrName $containerInfo.AcrName
    
    # Display the deployment results
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Your Flask CRUD app has been deployed with a private IP: $($deploymentOutputs.containerIPv4Address.value)" -ForegroundColor Cyan
    Write-Host "The Application Gateway has been configured to provide public access to your app." -ForegroundColor Green
    Write-Host "You can access the Flask CRUD app publicly at:" -ForegroundColor Green
    Write-Host "  - Public IP: http://$($deploymentOutputs.appGatewayPublicIp.value)" -ForegroundColor Cyan
    Write-Host "  - DNS Name: http://$($deploymentOutputs.appGatewayFQDN.value)" -ForegroundColor Cyan
    
    # If HTTPS is enabled, show HTTPS URL too
    $params = Get-Content -Raw -Path $ParametersFile | ConvertFrom-Json
    if ($params.parameters.enableHttps -and $params.parameters.enableHttps.value -eq $true) {
        Write-Host "HTTPS has been configured. You can also access your app securely at:" -ForegroundColor Green
        if ($params.parameters.httpsHostName -and -not [string]::IsNullOrEmpty($params.parameters.httpsHostName.value)) {
            Write-Host "  - HTTPS URL: https://$($params.parameters.httpsHostName.value)" -ForegroundColor Cyan
        } else {
            Write-Host "  - HTTPS URL: https://$($deploymentOutputs.appGatewayPublicIp.value)" -ForegroundColor Cyan
        }
    }
} catch {
    Write-Error "An error occurred: $_"
    exit 1
} 