# Azure Infrastructure-as-Code: Flask CRUD Application Deployment

## Introduction
This project demonstrates how to deploy a Flask CRUD web application to Azure using Infrastructure as Code (IaC) with Bicep templates. The assignment aims to show the implementation of cloud infrastructure automation, focusing on containerization, networking, security, and monitoring in Azure. 

By leveraging IaC principles, we can create reproducible, consistent, and version-controlled infrastructure deployments. This approach eliminates manual configuration and ensures that the infrastructure can be consistently reproduced in different environments.

## Architecture

![Azure Architecture Diagram](https://i.imgur.com/example.png)

*Note: Replace with your architecture diagram using Azure Icons from diagrams.net*

## Components

### Core Resources
1. **Azure Container Registry (ACR)** - Private registry for storing the Flask CRUD container image
2. **Azure Container Instance (ACI)** - Serverless container runtime for the Flask application
3. **Virtual Network & Subnet** - Dedicated network environment with proper isolation
4. **Network Security Groups (NSGs)** - Traffic filtering for both container and Application Gateway
5. **Application Gateway** - Layer 7 load balancer providing public access with SSL termination
6. **Log Analytics Workspace** - Centralized logging for container monitoring

### Security Features
1. **Private Network** - Container runs in a private subnet without direct internet access
2. **NSG Rules** - Only required traffic flows in and out (HTTP/HTTPS)
3. **SSL Certificate** - HTTPS encryption for secure client communication
4. **ACR Token** - Least privilege access for container image pulls

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.30.0 or higher)
- [Docker](https://www.docker.com/get-started)
- [Git](https://git-scm.com/downloads)
- PowerShell 7.0+ 
- Azure subscription
- Domain name for SSL (optional for HTTPS)

## Deployment

### 1. Clone the repository

```powershell
git clone https://github.com/yourusername/Assignment-2-Azure-Infrastructure-as-Code.git
cd Assignment-2-Azure-Infrastructure-as-Code
```

### 2. Update parameters

Edit `bicep/main.parameters.json` to replace placeholders with your initials:

```json
{
    "parameters": {
        "initials": {
            "value": "YOUR"  # Replace with your initials
        }
    }
}
```

### 3. Deploy the infrastructure

Run the deployment script with your initials and preferred region:

```powershell
.\deploy.ps1 -InitialsPrefix "YOUR" -Location "westeurope"
```

The script performs the following actions:
1. Creates a resource group with your initials
2. Clones the Flask CRUD application repository if not present
3. Builds and tags the Docker container image
4. Creates an Azure Container Registry using Bicep
5. Pushes the container image to your private ACR
6. Creates an ACR token with minimal pull permissions
7. Deploys the full infrastructure using Bicep templates:
   - Virtual Network with subnets for ACI and Application Gateway
   - Network Security Groups with appropriate rules
   - Log Analytics workspace for monitoring
   - Azure Container Instance running in the private subnet
   - Application Gateway providing public access with health probes

### 4. Configure SSL (Optional)

To enable HTTPS:

1. Set up DNS A record pointing to the Application Gateway public IP
2. Generate an SSL certificate (using Let's Encrypt or similar)
3. Install the certificate on Application Gateway:

```powershell
# Upload SSL certificate to Application Gateway
$resourceGroup = "rg-YOUR-flask-crud"
$appGatewayName = "appgw-YOUR-flask"

az network application-gateway ssl-cert create `
  --resource-group $resourceGroup `
  --gateway-name $appGatewayName `
  --name "sslCert" `
  --cert-file "path/to/certificate.pfx" `
  --cert-password "your-password"

# Configure HTTPS listener and routing rule
az network application-gateway frontend-port create `
  --resource-group $resourceGroup `
  --gateway-name $appGatewayName `
  --name "port443" `
  --port 443

az network application-gateway http-listener create `
  --resource-group $resourceGroup `
  --gateway-name $appGatewayName `
  --name "httpsListener" `
  --frontend-port "port443" `
  --ssl-cert "sslCert" `
  --frontend-ip "appGatewayFrontendIP"

az network application-gateway rule create `
  --resource-group $resourceGroup `
  --gateway-name $appGatewayName `
  --name "httpsRule" `
  --http-listener "httpsListener" `
  --rule-type "Basic" `
  --address-pool "flaskCrudBackendPool" `
  --http-settings "flaskCrudHttpSettings" `
  --priority 200
```

### 5. Access the application

After deployment completes, you can access your application:
- HTTP: http://<app-gateway-public-ip>
- HTTPS: https://your-domain-name.example.com (if SSL configured)

## Infrastructure Details

### Bicep Structure

```
bicep/
  ├── main.bicep                  # Main deployment template
  ├── main.parameters.json        # Deployment parameters
  └── modules/
      ├── acr.bicep               # Azure Container Registry
      ├── acr-token.bicep         # ACR Token with least privilege
      ├── aci.bicep               # Azure Container Instance
      ├── vnet.bicep              # Virtual Network with subnets
      ├── nsg.bicep               # Container NSG
      ├── nsg-appgw.bicep         # Application Gateway NSG
      ├── loganalytics.bicep      # Log Analytics workspace
      └── appgateway.bicep        # Application Gateway
```

### Network Security 

The Flask CRUD application is protected with multiple security layers:

1. **Container Subnet NSG**:
   - Allows HTTP (port 80) from Application Gateway subnet only
   - Denies all other inbound traffic
   - Allows outbound traffic for container operation

2. **Application Gateway NSG**:
   - Allows HTTP (port 80) and HTTPS (port 443) from the internet
   - Allows health probe traffic
   - Denies all other inbound traffic

### Container Configuration

The Flask CRUD application runs with optimized settings:

1. **Resource Allocation**:
   - 1 CPU core
   - 1GB memory

2. **Health Probes**:
   - Liveness probe: Ensures container is responsive
   - Readiness probe: Confirms application is ready to receive traffic

3. **Network Configuration**:
   - Private IP address (no direct internet exposure)
   - ACR authentication for image pulling

### Monitoring and Logging

All container logs are sent to Azure Monitor through Log Analytics:

1. **Container Insights**:
   - Container performance metrics
   - Application logs
   - Container health status

2. **Application Gateway Logs**:
   - Access logs
   - Performance logs
   - Firewall logs (if WAF enabled)

## Best Practices Implemented

1. **Infrastructure as Code**
   - Modular Bicep templates for reusability
   - Parameter files for environment-specific values
   - Idempotent deployments

2. **Security**
   - Network segmentation with VNet and subnets
   - NSG rules following least privilege
   - HTTPS for encrypted communication
   - ACR token with minimal permissions

3. **Resource Optimization**
   - Right-sized container resources
   - Standard_v2 tier for Application Gateway (cost-effective)

4. **Monitoring**
   - Centralized logging with Log Analytics
   - Health probes for application availability

## Cleanup

After demonstrating your assignment, delete all Azure resources to save credits:

```powershell
az group delete --name rg-YOUR-flask-crud --yes
```

## References

- [Azure Container Instances Documentation](https://docs.microsoft.com/en-us/azure/container-instances/)
- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Flask CRUD Application](https://github.com/gurkanakdeniz/example-flask-crud)
- [Azure Application Gateway Documentation](https://docs.microsoft.com/en-us/azure/application-gateway/)
- [Azure Log Analytics Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview) 