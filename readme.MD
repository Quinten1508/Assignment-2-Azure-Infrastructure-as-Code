# Azure Infrastructure-as-Code Assignment

This project deploys a Flask CRUD application to Azure using Infrastructure-as-Code (Bicep).

## Architecture

This solution deploys:
- Azure Container Registry (ACR) for storing the container image
- Azure Container Instance (ACI) for running the application
- Virtual Network with a dedicated subnet
- Network Security Group to control traffic
- Log Analytics workspace for monitoring

The Flask application is containerized and deployed to ACI within a dedicated subnet.

## Prerequisites

- Azure CLI installed
- Azure PowerShell module installed
- Docker installed
- PowerShell 5.1 or later

## Deployment Instructions

1. Clone this repository
2. Run the deployment script:

```powershell
.\deploy.ps1
```

The script will:
- Log in to Azure
- Create a resource group
- Build the Docker container
- Deploy Azure resources using Bicep
- Push the container to ACR
- Deploy the container to ACI

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Cloud                          │
│                                                         │
│  ┌───────────────┐         ┌───────────────────────┐   │
│  │               │         │ Virtual Network       │   │
│  │ Azure         │         │  ┌─────────────────┐  │   │
│  │ Container     │ pulls   │  │ NSG            │  │   │
│  │ Registry      │◄────────┼──┤                │  │   │
│  │               │         │  │ ┌─────────────┐│  │   │
│  └───────────────┘         │  │ │Azure       ││  │   │
│                            │  │ │Container   ││  │   │
│                            │  │ │Instance    ││  │   │
│  ┌───────────────┐         │  │ │           ││  │   │
│  │ Log Analytics │         │  │ │ Flask App ││  │   │
│  │ Workspace     │◄────────┼──┼─┤           ││  │   │
│  │               │   logs  │  │ └─────────────┘│  │   │
│  └───────────────┘         │  └─────────────────┘  │   │
│                            └───────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Implemented Best Practices

- Application runs in a dedicated VNET and subnet
- Network traffic is restricted with NSG rules (only HTTP on port 80)
- All container logs are sent to Azure Monitor
- Container uses minimal resources (1 CPU, 1.5 GB memory)
- Uses Infrastructure-as-Code for repeatable deployments

## Author
Quinten De Meyer (QDM) 