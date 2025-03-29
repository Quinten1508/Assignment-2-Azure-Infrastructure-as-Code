# Security Best Practices

## Credential Management

The previous service principal secret has been revoked and a new one has been generated. Follow these steps to securely use the new credentials:

### 1. NEVER commit credentials to source control

The old secret was exposed in your repository. This is a security risk as anyone with access to the repository can use these credentials to access your Azure resources.

### 2. Use environment variables instead of hardcoded credentials

Run the `set-credentials.ps1` script to set environment variables for your PowerShell session:

```powershell
# From the project root
./set-credentials.ps1
```

Then update your code to use environment variables:

```powershell
# Instead of hardcoded values like:
# $clientId = "00821023-ae1d-446f-9e04-fb7cffa39f36"
# $clientSecret = "some-secret"

# Use environment variables:
$clientId = $env:AZURE_CLIENT_ID
$clientSecret = $env:AZURE_CLIENT_SECRET
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$tenantId = $env:AZURE_TENANT_ID
```

Monitor your Azure Activity Logs for any suspicious activity related to the compromised credentials:

```powershell
az monitor activity-log list --start-time 2025-03-25 --query "[?contains(caller, '00821023-ae1d-446f-9e04-fb7cffa39f36')].{Caller:caller, Operation:operationName, Time:eventTimestamp, Status:status}"
``` 