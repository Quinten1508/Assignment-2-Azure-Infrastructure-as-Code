# Azure Flask CRUD Application Deployment

This repository contains Infrastructure-as-Code (IaC) for deploying a containerized Flask CRUD application to Azure using Bicep templates and PowerShell automation.

## Deployment Architecture

![Architecture Diagram](architecture-diagram.png)

*Note: Add an architecture diagram using diagrams.net with Azure icons before submission.*

## What the Deployment Script Does

The `deploy.ps1` script automates the entire deployment process with zero user interaction required. Here's what it does:

### 1. Initial Setup and Authentication
- Sets resource naming conventions with personalized prefix (`QDM`)
- Implements silent authentication using service principal, environment variables, or managed identity
- Creates a resource group in West Europe

### 2. Application Preparation
- Checks for the Flask CRUD application locally
- Clones the application from GitHub if not present
- Verifies Docker availability for local container builds

### 3. Infrastructure Deployment
- **Azure Container Registry (ACR)**
  - Creates a private container registry for image storage
  - Configures least-privilege access tokens

- **Networking Configuration**
  - Establishes a dedicated virtual network (`10.0.0.0/16`)
  - Creates a subnet (`10.0.0.0/24`) with Container Instance delegation
  - Implements network security groups allowing only HTTP traffic (port 80)

- **Monitoring Setup**
  - Creates a Log Analytics workspace
  - Configures container logging to Azure Monitor

### 4. Container Deployment
- Builds the Flask application container image
- Pushes the image to Azure Container Registry
- Deploys the container to Azure Container Instance with:
  - Network integration (runs in the dedicated subnet)
  - Public IP address for access
  - Log Analytics integration
  - Proper resource sizing (1 CPU, 2GB memory)

### 5. Best Practices Implementation
- **Security**
  - Network isolation through dedicated VNet
  - Restricted inbound/outbound traffic with NSG rules
  - Principle of least privilege for all access

- **Monitoring**
  - Centralized logging with Azure Monitor
  - Container health metrics

- **Cost Optimization**
  - Right-sized resources to minimize Azure costs
  - Basic SKU selection where appropriate

## Running the Deployment

To deploy the application:

```powershell
# Just run the deployment script
./deploy.ps1
```

The script handles everything automatically, including:
- Authentication
- Resource provisioning
- Container building and pushing
- Container instance deployment

## Accessing the Application

After deployment completes, the script outputs:
- The container's public IP address
- Log Analytics workspace URL for monitoring

Access the application at: `http://<container-ip-address>`

## Resource Cleanup

To avoid unnecessary Azure costs, run:

```powershell
az group delete --name rg-QDM-flask-crud --yes
```

## Technical Components

The deployment uses modular Bicep templates:
- `main.bicep`: Orchestrates the deployment workflow
- `modules/acr.bicep`: Container registry setup
- `modules/network.bicep`: VNet, subnet and NSG configuration
- `modules/log-analytics.bicep`: Monitoring setup
- `modules/container-instance.bicep`: Container deployment with VNet integration 