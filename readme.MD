# Azure Infrastructure-as-Code Assignment

This project demonstrates deploying a Flask CRUD application to Azure Container Instances using Infrastructure-as-Code (IaC) with Bicep templates. The deployment follows Azure best practices for networking, security, and monitoring.

## Architecture

![Azure Architecture Diagram](https://i.imgur.com/example.png)

*Note: Create an architecture diagram using [diagrams.net](https://app.diagrams.net/) with Azure icons and replace the example link above with your own diagram.*

## Components

1. **Azure Container Registry (ACR)** - Stores the Flask CRUD container image
2. **Virtual Network & Subnet** - Dedicated network environment for the container
3. **Network Security Group (NSG)** - Controls network traffic with rules
4. **Azure Container Instance (ACI)** - Runs the Flask CRUD application
5. **Log Analytics Workspace** - Collects and analyzes container logs

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Docker](https://www.docker.com/get-started)
- [Git](https://git-scm.com/downloads)
- Azure subscription
- PowerShell 7.0+

## Deployment

### 1. Clone the repository

```powershell
git clone https://github.com/yourusername/Assignment-2-Azure-Infrastructure-as-Code.git
cd Assignment-2-Azure-Infrastructure-as-Code
```

### 2. Update parameters

Edit `bicep/main.parameters.json` to replace "YOUR" with your initials.

### 3. Deploy the infrastructure

Run the deployment script:

```powershell
.\deploy.ps1 -InitialsPrefix "YOUR" -Location "westeurope"
```

The script performs the following actions:
1. Creates a resource group
2. Clones the Flask CRUD repository
3. Builds and pushes the container image to ACR
4. Creates an ACR token with least privilege
5. Deploys all Azure resources using Bicep templates

### 4. Access the application

After deployment, the script will output the URL to access the Flask CRUD application.

## Project Structure

```
├── bicep/
│   ├── main.bicep                     # Main Bicep template
│   ├── main.parameters.json           # Parameters for deployment
│   └── modules/
│       ├── acr.bicep                  # Azure Container Registry
│       ├── aci.bicep                  # Azure Container Instance
│       ├── loganalytics.bicep         # Log Analytics workspace
│       ├── nsg.bicep                  # Network Security Group
│       └── vnet.bicep                 # Virtual Network
├── example-flask-crud/                # Flask CRUD application
├── Dockerfile                         # Container image definition
├── deploy.ps1                         # Deployment script
└── README.md                          # Project documentation
```

## Best Practices Implemented

1. **Network Security**
   - Dedicated VNet and subnet for the container
   - NSG with specific rules for HTTP traffic
   - Deny all other inbound traffic

2. **Least Privilege**
   - ACR token with only necessary permissions

3. **Monitoring**
   - Container logs sent to Azure Monitor

4. **Resource Optimization**
   - Minimal container resources (1 CPU core, 1GB memory)

## Cleanup

After demonstrating your assignment, delete all Azure resources to save credits:

```powershell
az group delete --name rg-YOUR-flask-crud --yes
```

## References

- [Azure Container Instances Documentation](https://docs.microsoft.com/en-us/azure/container-instances/)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Flask CRUD Application](https://github.com/gurkanakdeniz/example-flask-crud) 