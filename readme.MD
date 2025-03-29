# Assignment 2: Azure Infrastructure-as-Code

## Introduction
For this assignment, I deployed a Flask CRUD application to Azure using Infrastructure as Code (IaC) with Bicep templates. The goal was to demonstrate understanding of cloud infrastructure automation, focusing on containerization, networking, security, and monitoring in Azure.

I chose Bicep over ARM templates for its improved readability and modularity. This implementation shows how IaC can create reproducible, consistent, and version-controlled infrastructure deployments, eliminating manual configuration errors and ensuring infrastructure can be consistently reproduced.

## Architecture Diagram
![Azure Architecture](./architecture-diagram.png)

*The architecture diagram was created using diagrams.net with the Azure Icon set, showing all components and their relationships.*

## Implementation Details

### Container Image Creation
I used the [example-flask-crud](https://github.com/gurkanakdeniz/example-flask-crud) repository as the base application. I containerized this application with a custom Dockerfile:

```dockerfile
FROM mcr.microsoft.com/azure-functions/python:4-python3.9

WORKDIR /app

# Copy from local directory rather than assuming a specific folder structure
COPY . /app/

# Install dependencies - use requirements.txt from the Flask app
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Create startup script
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'cd /app' >> /app/start.sh && \
    echo 'python -c "from app import db; db.create_all()"' >> /app/start.sh && \
    echo 'python -m flask run --host=0.0.0.0 --port=80' >> /app/start.sh && \
    chmod +x /app/start.sh

ENV FLASK_APP=crudapp.py \
    PYTHONUNBUFFERED=1 \
    AzureWebJobsScriptRoot=/app \
    FLASK_ENV=production

EXPOSE 80

CMD ["/app/start.sh"]
```

This Dockerfile:
- Uses a Python 3.9 base image suitable for Azure Functions
- Sets up a custom startup script to initialize the database and run Flask
- Exposes port 80 for HTTP traffic
- Configures necessary environment variables for Flask

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

#### Container Instance Module (aci.bicep)
This module deploys the container with appropriate configurations:

```bicep
resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: containerGroupName
  location: location
  properties: {
    containers: [
      {
        name: 'flask-crud-container'
        properties: {
          image: containerImageName
          ports: [
            {
              port: port
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          livenessProbe: {
            httpGet: {
              path: '/'
              port: port
              scheme: 'http'
            }
            initialDelaySeconds: 30
            periodSeconds: 30
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 3
          }
          readinessProbe: {
            httpGet: {
              path: '/'
              port: port
              scheme: 'http'
            }
            initialDelaySeconds: 15
            periodSeconds: 15
            timeoutSeconds: 5
            successThreshold: 1
            failureThreshold: 3
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Always'
    subnetIds: [
      {
        id: subnetId
      }
    ]
    ipAddress: {
      type: 'Private'
      ports: [
        {
          port: port
          protocol: 'TCP'
        }
      ]
    }
  }
}
```

#### Network Security Group (nsg.bicep)
This module implements security rules to protect the container:

```bicep
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
          description: 'Allow HTTP traffic to the container'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}
```

#### Application Gateway with SSL (appgateway.bicep)
This module configures the Application Gateway with HTTPS support:

```bicep
frontendPorts: [
  {
    name: 'appGatewayFrontendPort'
    properties: {
      port: frontendPort
    }
  }
  // Add HTTPS port if enabled
  {
    name: 'httpsPort'
    properties: {
      port: httpsPort
    }
  }
]
// Add SSL certificate if HTTPS is enabled
sslCertificates: enableHttps ? [
  {
    name: 'iacCertificate'
    properties: {
      data: sslCertificateData
      password: sslCertificatePassword
    }
  }
] : []

// HTTPS listeners configuration
httpListeners: concat([
  {
    name: 'flaskCrudListener'
    properties: {
      frontendIPConfiguration: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'appGatewayFrontendPort')
      }
      protocol: 'Http'
    }
  }
], enableHttps ? [
  {
    name: 'httpsListener'
    properties: {
      frontendIPConfiguration: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
      }
      frontendPort: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'httpsPort')
      }
      protocol: 'Https'
      sslCertificate: {
        id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGatewayName, 'iacCertificate')
      }
      hostName: httpsHostName
      requireServerNameIndication: !empty(httpsHostName)
    }
  }
] : [])
```

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
   - Created a dedicated `deploy-with-ssl.ps1` script for SSL deployments:

```powershell
# Azure Infrastructure-as-Code Deployment Script with SSL certificate
param (
    [Parameter(Mandatory = $true)]
    [string]$SslCertPath,
    
    [Parameter(Mandatory = $true)]
    [string]$SslCertPassword,
    
    [Parameter(Mandatory = $false)]
    [string]$HttpsHostName = "iac.quinten-de-meyer.be",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseCredentialsFile
)

# Call the main deployment script with SSL parameters
$deployParams = @{
    SslCertPath = $SslCertPath
    SslCertPassword = $SslCertPassword
    HttpsHostName = $HttpsHostName
}

if ($UseCredentialsFile) {
    $deployParams.Add("UseCredentialsFile", $true)
}

Write-Host "Starting deployment with SSL certificate..." -ForegroundColor Cyan

# Execute the main deployment script with SSL parameters
try {
    & .\deploy.ps1 @deployParams
} catch {
    Write-Error "An error occurred during deployment: $_"
    exit 1
}
```

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

I have successfully fulfilled all requirements of the Assignment 2: Azure Infrastructure-as-Code as outlined below:

### Step 1: Learn about Infrastructure-as-Code and Bicep templates
- Completed the MS Learn tutorials on IaC and Bicep
- Applied the learned concepts throughout the implementation
- Used Bicep as the primary IaC language for all deployments

### Step 2: Build the container image
- Created a Docker container based on the example-flask-crud application
- Built and tested the containerized application locally
- Optimized the container image size and configuration for Azure deployment

### Step 3: Create Azure Container Registry (ACR)
- Implemented an ACR using Bicep templates with appropriate SKU for cost efficiency
- Created ACR token with least privilege access to the registry
- Set up secure image push/pull workflows in the deployment scripts

### Step 4: Deploy the container to Azure Container Instance
- Deployed the container to ACI using modular Bicep templates
- Configured proper resource allocation (1 CPU, 1GB RAM) to save Azure credits
- Implemented health probes and restart policies for reliability

### Step 5: Implement best practices
- **VNet/Subnet**: Created a dedicated VNet and subnet for the container instance
- **Public IP**: Configured Application Gateway with a public IP for application access
- **HTTP on port 80**: Set up the container to serve HTTP traffic on port 80
- **Traffic Control**: Implemented NSG rules to allow only required traffic
- **Monitoring**: Configured container logs to stream to Azure Monitor

### Extra Features
I went beyond the basic requirements to implement additional security and usability features:

1. **SSL/HTTPS Support**:
   - Implemented HTTPS using Let's Encrypt certificates
   - Configured SSL termination at the Application Gateway
   - Created automated SSL certificate deployment scripts

2. **Custom Domain**:
   - Set up a custom domain "iac.quinten-de-meyer.be" for the application
   - Configured DNS records and domain validation
   - Integrated domain with SSL certificate for secure access

All resources were named following the required convention with my initials, and I ensured optimization of resource consumption to save Azure credits.

## Conclusion
Through this assignment, I demonstrated my understanding of Infrastructure as Code using Bicep templates to deploy a containerized application to Azure. I implemented security best practices, optimized resource usage, and ensured proper monitoring capabilities.

The solution is highly automated through PowerShell scripts and modular Bicep templates, meeting all the requirements specified in the assignment. I ensured all resource names include my initials (QDM) and optimized the resource consumption to save Azure credits. 