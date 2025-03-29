# Assignment 2: Azure Infrastructure-as-Code

## Introduction
This repository contains the infrastructure-as-code (IaC) implementation for deploying a Flask CRUD application to Azure using Bicep templates. The assignment focuses on automating the deployment of cloud infrastructure through code, which provides better consistency, repeatability, and version control compared to manual deployments.

The solution implements a containerized Flask application running in Azure Container Instances (ACI), with container images stored in Azure Container Registry (ACR). The application is exposed through an Application Gateway to provide secure public access.

## Architecture Diagram
![Azure Architecture](./architecture-diagram.png)

*Note: Please refer to the architecture diagram file in this repository. The diagram was created using diagrams.net with the Azure Icon set.*

## Implementation Steps

### Step 1: Create a Container Image
The application is based on the [example-flask-crud](https://github.com/gurkanakdeniz/example-flask-crud) repository. The Dockerfile in this repo builds the container image for the application.

```bash
# Build the Docker image
docker build -t flask-crud:latest .
```

### Step 2: Setup Azure Infrastructure with Bicep

#### Resource Group Creation
First, we create a resource group to contain all our Azure resources:

```powershell
az group create --name rg-qdm-flask-crud --location westeurope
```

#### Deploy Bicep Template
The main.bicep file deploys the following resources:
- Azure Container Registry (ACR)
- Virtual Network and Subnet for the ACI
- Network Security Groups with appropriate rules
- Azure Container Instance with the Flask application
- Application Gateway for public access
- Log Analytics workspace for monitoring

```powershell
az deployment group create --resource-group rg-qdm-flask-crud --template-file main.bicep
```

### Step 3: Push Image to Azure Container Registry
After ACR is provisioned, we push our container image:

```powershell
# Login to ACR
az acr login --name acrqdmcrud01

# Tag and push the image
docker tag flask-crud:latest acrqdmcrud01.azurecr.io/flask-crud:latest
docker push acrqdmcrud01.azurecr.io/flask-crud:latest
```

## Best Practices Implemented

### Network Security
- The container instance runs in a dedicated virtual network
- Network Security Groups (NSGs) restrict traffic with specific rules
- Only HTTP traffic on port 80 is allowed to the container
- Application Gateway handles public access and could be configured for SSL/TLS

### Resource Efficiency
- Container is configured with just 1 CPU core and 1GB of memory
- Resources are sized appropriately for the application needs
- Premium tier services are avoided where standard offerings are sufficient

### Monitoring
- All container logs are sent to Azure Monitor via Log Analytics workspace
- Health probes ensure the application is functioning correctly
- Application insights could be integrated for more detailed monitoring

### Security
- Container Registry access is limited with tokens providing least privilege
- Network isolation prevents direct access to the container
- Application Gateway can be configured with WAF (Web Application Firewall)

## HTTPS Configuration
For details on setting up HTTPS with Let's Encrypt certificates on the Application Gateway, please refer to the [SSL Configuration Guide](./ssl_guide.md).

## Cleanup
To avoid unnecessary Azure costs, remember to delete all resources when they are no longer needed:

```powershell
az group delete --name rg-qdm-flask-crud --yes
```

## Bicep Template Structure
- `main.bicep`: Main template file that orchestrates the deployment
- `acr.bicep`: Module for Azure Container Registry
- `vnet.bicep`: Module for Virtual Network and Subnet configuration
- `aci.bicep`: Module for Azure Container Instance
- `appgw.bicep`: Module for Application Gateway
- `loganalytics.bicep`: Module for Log Analytics workspace

Each module follows best practices for Bicep, including appropriate comments, parameter validation, and output variables.

## Considerations and Limitations
- For production workloads, consider using Azure Kubernetes Service for better scalability
- This implementation doesn't include CI/CD pipelines for automated deployments
- For a more resilient solution, implement multiple instances across availability zones
- Consider implementing backup and disaster recovery strategies 