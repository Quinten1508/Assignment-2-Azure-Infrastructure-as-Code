# Assignment 2: Azure Infrastructure-as-Code

## Introduction and Context

This project demonstrates the deployment of a Flask CRUD application to Azure using Infrastructure-as-Code (IaC) techniques with Bicep templates. The goal is to leverage IaC to create reproducible, version-controlled cloud infrastructure that follows Azure best practices.

The application is a simple Flask-based CRUD (Create, Read, Update, Delete) web application that allows users to manage database records through a web interface. By containerizing this application and deploying it to Azure Container Instances, we demonstrate cloud-native deployment techniques with security and monitoring best practices.

## Architecture Diagram

![Azure Architecture Diagram]
*Note: Create an Azure architecture diagram using diagrams.net with the Azure Icon set and place it in the repository before submission.*

## Implementation Overview

This solution implements:

1. **Containerized Application**: Flask CRUD app packaged in a Docker container
2. **Private Container Registry**: Azure Container Registry (ACR) to store container images
3. **Containerized Deployment**: Azure Container Instance (ACI) to run the application
4. **Network Isolation**: Dedicated Virtual Network with NSG security rules
5. **Monitoring**: Log Analytics integration for centralized logging and monitoring

## Deployment Steps

### Step 1: Build the Container Image

The Flask CRUD application is containerized using Docker:
```bash
# Build the container image locally
docker build -t flask-crud-app:latest .
```

### Step 2: Create Azure Container Registry

The ACR is provisioned using Bicep templates to store the container image securely:
```bash
# Deploy ACR using Bicep
az deployment group create --resource-group rg-QDM-flask-crud --template-file main.bicep
```

The ACR implementation includes:
- Basic SKU to minimize costs while providing essential functionality
- Admin access for authentication
- Token-based access with minimal permissions following the principle of least privilege

### Step 3: Push the Image to ACR

```bash
# Authenticate with ACR
az acr login --name acrQDMcrud

# Tag and push the image
docker tag flask-crud-app:latest acrQDMcrud.azurecr.io/flask-crud-app:latest
docker push acrQDMcrud.azurecr.io/flask-crud-app:latest
```

### Step 4: Deploy to Azure Container Instance

The container is deployed to ACI with VNet integration using Bicep templates:
```bash
# Deploy ACI using Bicep
az deployment group create --resource-group rg-QDM-flask-crud --template-file main.bicep
```

### Step 5: Best Practices Implementation

The deployment includes several best practices:

1. **Network Security**:
   - Dedicated VNet and subnet for container isolation
   - NSG rules limiting inbound traffic to HTTP port 80 only
   - Explicit outbound rules for Azure Monitor and ACR only

2. **Monitoring**:
   - Log Analytics workspace integration
   - Container logs forwarded to Azure Monitor
   - Custom dashboard for application monitoring

3. **Resource Optimization**:
   - Right-sized compute resources (1 CPU, 2GB memory)
   - Basic SKU selection to minimize costs

## Resource Details

All resources are created with the "QDM" prefix for identification:

- **Resource Group**: `rg-QDM-flask-crud`
- **Container Registry**: `acrQDMcrud` (Basic SKU)
- **Container Instance**: `aci-QDM-flask-crud` (1 CPU, 2GB memory)
- **Virtual Network**: `vnet-QDM-crud` (10.0.0.0/16)
- **Subnet**: `subnet-QDM-aci` (10.0.1.0/24)
- **NSG**: `subnet-QDM-aci-nsg`
- **Log Analytics**: `la-QDM-crud`

## Accessing the Application

After deployment, the application can be accessed at:
```
http://<container-ip-address>
```

The exact IP address is available in the deployment outputs.

## Monitoring and Logs

To view container logs in Azure Monitor:
1. Navigate to the Azure Portal
2. Go to the Log Analytics workspace `la-QDM-crud`
3. Select "Logs" and query container insights

## Cleanup Instructions

To avoid unnecessary Azure costs, delete all resources after demonstration:

```bash
az group delete --name rg-QDM-flask-crud --yes
```

## Additional Information

- The complete Infrastructure-as-Code is available in this repository
- All code is thoroughly commented for educational purposes
- The deployment is fully automated using either the PowerShell script or Bicep templates 