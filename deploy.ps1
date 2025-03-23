# Deployment script for Flask CRUD application to Azure
# Quinten De Meyer (QDM)

# Parameters
$resourceGroupName = "qdm-flask-crud-rg"
$location = "westeurope"
$templateFile = "main.bicep"
$containerImageName = "flask-crud"
$containerImageTag = "latest"

# Step 1: Ensure Az module is installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Az module not found. Installing..."
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}

# Step 2: Login to Azure
Connect-AzAccount

# Step 3: Create resource group
Write-Host "Creating resource group $resourceGroupName..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# Step 4: Build the Docker image
Write-Host "Building Docker image..."
docker build -t $containerImageName`:$containerImageTag .

# Step 5: Deploy Azure resources using Bicep
Write-Host "Deploying Azure resources..."
$deployment = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
    -TemplateFile $templateFile `
    -namePrefix "qdm" `
    -imageName $containerImageName `
    -imageTag $containerImageTag

# Get ACR details
$acrLoginServer = $deployment.Outputs.acrLoginServer.Value

# Step 6: Login to ACR
Write-Host "Logging in to ACR..."
$acrName = ($acrLoginServer -split '\.')[0]
$acrCredentials = Get-AzContainerRegistryCredential -ResourceGroupName $resourceGroupName -Name $acrName
$acrUsername = $acrCredentials.Username
$acrPassword = $acrCredentials.Password | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($acrUsername, $acrPassword)

docker login $acrLoginServer -u $acrUsername -p $acrPassword

# Step 7: Tag and push the image to ACR
Write-Host "Tagging and pushing image to ACR..."
docker tag $containerImageName`:$containerImageTag $acrLoginServer/$containerImageName`:$containerImageTag
docker push $acrLoginServer/$containerImageName`:$containerImageTag

# Step 8: Display container IP address
Write-Host "Deployment completed successfully!"
Write-Host "Container IP Address: $($deployment.Outputs.containerIPAddress.Value)"
Write-Host "Application will be available at: http://$($deployment.Outputs.containerIPAddress.Value)"
Write-Host "Note: It may take a few minutes for the container to start and the application to be accessible." 