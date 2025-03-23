# Assignment 2: Azure Infrastructure-as-Code

## Introduction
This project demonstrates the implementation of Infrastructure-as-Code (IaC) on Azure using Bicep templates. The assignment focuses on deploying a Flask-based CRUD application containerized using Docker and hosted on Azure Container Instances (ACI). The deployment follows industry best practices for security, monitoring, and network configuration.

## Architecture Diagram
[Include Azure architecture diagram here - will be created using diagrams.net with Azure icon set]

## Project Components
- **Container Image**: Based on the [example-flask-crud](https://github.com/gurkanakdeniz/example-flask-crud) application
- **Azure Container Registry (ACR)**: Securely stores our container image
- **Azure Container Instance (ACI)**: Hosts the containerized application
- **Virtual Network & Subnet**: Isolates the application for improved security
- **Network Security Group**: Controls inbound and outbound traffic
- **Azure Monitor**: Provides logging and monitoring capabilities

## Implementation Steps

### 1. Creating the Container Image
The container image is built based on the example-flask-crud application. The Dockerfile configures the application to run on port 80.

### 2. Azure Container Registry Setup with Bicep
The ACR is provisioned using Bicep templates to store the container image securely. A token with the least privilege necessary is created to access the registry.

### 3. Container Deployment with ACI
The container instance is deployed using Bicep templates, configuring it to pull the image from our ACR.

### 4. Networking and Security Configuration
- Custom VNet and subnet created specifically for the application
- Public IP address assigned to make the application accessible
- NSG rules configured to allow only HTTP traffic on port 80
- Outbound traffic restricted to necessary connections only

### 5. Monitoring and Logging
All container logs are configured to be sent to Azure Monitor for centralized logging and monitoring.

## Required Files
- `main.bicep`: Main Bicep template orchestrating the deployment
- `acr.bicep`: Module for Azure Container Registry
- `aci.bicep`: Module for Azure Container Instance
- `network.bicep`: Module for VNet, subnet, and NSG configuration
- `monitoring.bicep`: Module for Azure Monitor configuration

## Deployment Instructions
1. Ensure you have Azure CLI installed and are logged in
2. Build the container image locally
3. Deploy the Bicep templates:
   ```
   az deployment group create --resource-group <RG-NAME> --template-file main.bicep
   ```
4. Push the container image to the ACR
5. The application will be accessible via the public IP address

## Best Practices Implemented
- **Security**: Least privilege access, network isolation, restricted traffic flow
- **Performance**: Right-sized container instances
- **Monitoring**: Comprehensive logging via Azure Monitor
- **Infrastructure-as-Code**: Complete automation of infrastructure deployment
- **Resource Management**: Resources tagged appropriately for management

## Cleanup Instructions
To delete all Azure resources after demonstration:
1. Navigate to the Azure Portal
2. Go to "All Resources"
3. Delete all resources associated with this project to conserve Azure credits

## References
- [Microsoft Learn - Introduction to Infrastructure as Code](https://learn.microsoft.com/en-us/training/modules/introduction-to-infrastructure-as-code-using-bicep/)
- [Microsoft Learn - Build your first Bicep template](https://learn.microsoft.com/en-us/training/modules/build-first-bicep-template/)
- [Azure Container Registry Documentation](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-tutorial-prepare-acr)
- [Azure Container Instances with Bicep](https://learn.microsoft.com/en-us/azure/container-instances/container-instances-quickstart-bicep)
