# Assignment 2: Azure Infrastructure-as-Code

This project deploys a Flask CRUD application to Azure using Infrastructure-as-Code techniques. The deployment can be done either using PowerShell scripts or Bicep templates.

## Project Overview

This project demonstrates how to:
1. Build a containerized Flask CRUD application
2. Push the container to Azure Container Registry
3. Deploy the container to Azure Container Instances
4. Configure best practices for Azure deployments

## Project Structure

```
.
├── deploy.ps1                 # PowerShell deployment script
├── Dockerfile                 # Container definition for Flask app
├── example-flask-crud/        # Source code for the Flask CRUD application
├── main.bicep                 # Main Bicep deployment template
├── main.parameters.json       # Parameters for Bicep deployment
└── modules/                   # Bicep modules for modular deployment
    ├── acr.bicep              # Azure Container Registry module
    ├── container-instance.bicep # Azure Container Instance module
    ├── log-analytics.bicep    # Log Analytics workspace module
    └── network.bicep          # VNet and subnet module with NSG
```

## Quick Start - PowerShell Script

The simplest way to deploy is using the PowerShell script:

```powershell
./deploy.ps1
```

The script will:
1. Automatically check if you're logged in to Azure and handle authentication
2. Build the Docker container for the Flask CRUD app
3. Create an Azure Container Registry and push the image
4. Deploy the container to Azure Container Instances
5. Output the URL where you can access your application

## Bicep Deployment (Alternative)

For a more granular and modular approach, you can use Bicep:

```powershell
# Deploy using Bicep templates
az deployment group create --resource-group rg-QDM-flask-crud --template-file main.bicep
```

The Bicep deployment creates:
- Virtual Network with a dedicated subnet for container instances
- Network Security Group with appropriate rules
- Azure Container Registry with token-based authentication
- Log Analytics workspace for monitoring
- Azure Container Instance with VNet integration

## Resources Created

Resources are created with the prefix "QDM" (configurable):

- Resource Group: `rg-QDM-flask-crud`
- Container Registry: `acrqdmcrud`
- Container Instance: `aci-qdm-flask-crud`
- Virtual Network (Bicep only): `vnet-QDM-crud`
- Subnet (Bicep only): `subnet-QDM-container`
- Network Security Group (Bicep only): `subnet-QDM-container-nsg`

## Application Access

After deployment, the application will be available at:
- PowerShell deployment: http://flask-crud-qdm.westeurope.azurecontainer.io
- Bicep deployment: See the outputs of the deployment for the exact URL

## Docker Configuration

The current Dockerfile uses:
- Base image: `mcr.microsoft.com/azure-functions/python:4-python3.9`
- Flask's built-in development server (for simplicity)
- Database initialization at container start

## Monitoring and Logs

To view the container logs:

```powershell
az container logs --resource-group rg-QDM-flask-crud --name aci-qdm-flask-crud
```

## Best Practices Implemented

1. **Security**:
   - Container runs in a dedicated VNet (Bicep deployment)
   - Network Security Group restricts inbound traffic to port 80
   - Uses Microsoft's official Azure container image

2. **Performance & Cost Optimization**:
   - Minimal compute resources (1 CPU core, 1GB memory)
   - Container registry uses Basic SKU to minimize costs

3. **Infrastructure as Code**:
   - Complete automation for repeatable deployments
   - Modular Bicep templates for maintainability
   - PowerShell script for simplified deployment

## Cleanup

After demonstrating your assignment, delete all resources to save Azure credits:

```powershell
az group delete --name rg-QDM-flask-crud --yes --no-wait
``` 