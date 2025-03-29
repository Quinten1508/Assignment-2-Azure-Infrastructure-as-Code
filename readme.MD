# Assignment 2: Azure Infrastructure-as-Code

## Introduction
For this assignment, I deployed a Flask CRUD application to Azure using Infrastructure as Code (IaC) with Bicep templates. The goal was to demonstrate understanding of cloud infrastructure automation, focusing on containerization, networking, security, and monitoring in Azure.

I chose Bicep over ARM templates for its improved readability and modularity. This implementation shows how IaC can create reproducible, consistent, and version-controlled infrastructure deployments, eliminating manual configuration errors and ensuring infrastructure can be consistently reproduced.

## Architecture Diagram
![Azure Architecture](./architecture-diagram.png)

*The architecture diagram was created using diagrams.net with the Azure Icon set, showing all components and their relationships.*

## Implementation Details

### Container Image Creation
I used the [example-flask-crud](https://github.com/gurkanakdeniz/example-flask-crud) repository as the base application. I containerized this application by:
- Creating a Dockerfile with optimized layers
- Building a container image with appropriate tags
- Testing the image locally before pushing to Azure

### Deployment Automation
I created a two-step deployment process:

1. **Service Principal Setup** - I developed a `set-credentials.ps1` script to:
   - Create a Service Principal with appropriate roles
   - Store credentials securely in a local file for automated deployments
   - This enabled non-interactive deployments with least-privilege principles

2. **Deployment Script** - I wrote a comprehensive `deploy.ps1` script that:
   - Handles authentication fallback (checks if logged in, uses SP if available)
   - Creates resource groups dynamically if they don't exist
   - Validates Bicep templates before deployment
   - Builds and pushes container images to ACR
   - Manages the full deployment lifecycle with error handling

Example of the authentication logic implemented:

```powershell
# Check if logged in to Azure
$loginStatus = az account show --query "user.name" -o tsv 2>$null
if (-not $loginStatus) {
    Write-Host "Not logged in to Azure. Attempting to log in with service principal..."
    if (Test-Path -Path "sp-credentials.json") {
        $spCreds = Get-Content "sp-credentials.json" | ConvertFrom-Json
        az login --service-principal --username $spCreds.appId --password $spCreds.password --tenant $spCreds.tenant
    } else {
        Write-Host "No service principal credentials found. Please log in interactively."
        az login
    }
}
```

### Bicep Implementation
I created modular Bicep templates with a focus on maintainability and reuse:

- **main.bicep**: Orchestrates the entire deployment by calling modules in the correct order
- **acr.bicep**: Provisions an Azure Container Registry with proper access controls
- **vnet.bicep**: Creates a virtual network with separate subnets for container instances and Application Gateway
- **aci.bicep**: Deploys the container instance with health probes and resource constraints
- **appgw.bicep**: Sets up Application Gateway with proper routing rules and backend pools
- **loganalytics.bicep**: Configures logging and monitoring for all resources

I ensured all resources used my initials (QDM) in their names to identify them easily. Each resource was properly tagged and configured with appropriate dependencies to ensure proper deployment order.

### Network Security Implementation
For security, I implemented:

1. **Network Isolation**:
   - Created a dedicated VNet with separate subnets
   - Placed container instances in a private subnet
   - Used NSGs to restrict traffic between subnets

2. **Traffic Filtering**:
   - Created NSG rules to only allow HTTP/80 traffic to containers
   - Restricted outbound traffic to essential services
   - Configured Application Gateway to be the only entry point

3. **HTTPS Configuration**:
   - Set up Let's Encrypt certificate generation
   - Configured SSL termination at the Application Gateway
   - Implemented proper certificate management and renewal (documented in ssl_guide.md)

### SSL/HTTPS Implementation
I added HTTPS support to the application with the following features:

1. **Application Gateway SSL Support**:
   - Modified the Application Gateway Bicep template to support SSL certificates
   - Configured HTTPS listeners and routing rules
   - Implemented certificate handling in the deployment scripts

2. **Let's Encrypt Integration**:
   - Used Let's Encrypt for free, trusted SSL certificates
   - Created scripts to automate certificate conversion and deployment
   - Documented the full process in ssl_guide.md

3. **Deployment Options**:
   - Created a dedicated `deploy-with-ssl.ps1` script for SSL deployments
   - Added SSL parameters to the main deployment script
   - Provided options in the parameters file for persistent SSL configuration

Example of deploying with SSL:
```powershell
# Deploy with SSL certificate
.\deploy-with-ssl.ps1 -SslCertPath "C:\temp\certificate.pfx" -SslCertPassword "YourSecretPassword" -HttpsHostName "iac.quinten-de-meyer.be"
```

### Monitoring Setup
I implemented comprehensive monitoring:

- Configured container logs to stream to Log Analytics
- Set up health probes to monitor container availability
- Created dashboard visualizations for resource utilization
- Enabled diagnostic settings on Application Gateway and NSGs

## Requirements Fulfillment

### 1. ACR with Bicep
I successfully created an Azure Container Registry with the following features:
- Standard SKU for cost efficiency
- Geo-replication disabled to save Azure credits
- Admin account disabled for improved security
- Implemented token-based authentication with least privilege

### 2. ACI Deployment with Bicep
The container deployment includes:
- Resource constraints (1 CPU, 1GB RAM) for cost efficiency
- Health probes to ensure application availability
- Container restart policy set to Always for reliability
- Image registry credentials configured for private ACR

### 3. Network Configuration
I implemented the network requirements by:
- Creating a custom VNet/subnet for the container instance
- Configuring proper NSG rules to restrict traffic
- Setting up Application Gateway with a public IP
- Only allowing required traffic in/out of the container

### 4. Logging and Monitoring
For observability, I:
- Configured container logs to stream to Azure Monitor
- Created Log Analytics workspace for centralized logging
- Set up diagnostic settings on all key resources
- Implemented query-based alerting for critical conditions

## Challenges and Solutions
During the implementation, I encountered several challenges:

1. **Container Networking Issues**:
   - Problem: Initial deployment had connectivity issues between App Gateway and ACI
   - Solution: Implemented custom route tables and fixed NSG rules

2. **SSL Certificate Configuration**:
   - Problem: Let's Encrypt certificate required manual steps
   - Solution: Created detailed documentation (ssl_guide.md) for the process

3. **Image Deployment Timing**:
   - Problem: Container deployed before image was available
   - Solution: Added dependency chains and validation checks in the deployment script

## Conclusion
Through this assignment, I demonstrated my understanding of Infrastructure as Code using Bicep templates to deploy a containerized application to Azure. I implemented security best practices, optimized resource usage, and ensured proper monitoring capabilities.

The solution is highly automated through PowerShell scripts and modular Bicep templates, meeting all the requirements specified in the assignment. I ensured all resource names include my initials (QDM) and optimized the resource consumption to save Azure credits. 