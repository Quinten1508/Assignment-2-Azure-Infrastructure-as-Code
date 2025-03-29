# Script to set Azure credentials as environment variables
# IMPORTANT: Do not commit this file to source control with secrets

# Check if Az module is installed and import it
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Az module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
}

# Import Az modules
Import-Module Az.Accounts
Import-Module Az.Resources

# Set environment variables for the current session
$credentialsFile = "./sp-credentials.json"

if (Test-Path $credentialsFile) {
    try {
        $credentials = Get-Content -Raw -Path $credentialsFile | ConvertFrom-Json
        
        # Set environment variables
        $env:AZURE_CLIENT_ID = $credentials.clientId
        $env:AZURE_CLIENT_SECRET = $credentials.clientSecret
        $env:AZURE_SUBSCRIPTION_ID = $credentials.subscriptionId
        $env:AZURE_TENANT_ID = $credentials.tenantId
        
        Write-Host "Azure credentials have been set as environment variables for the current session." -ForegroundColor Green
        Write-Host "Use these environment variables in your scripts instead of hardcoded credentials." -ForegroundColor Green
    } catch {
        Write-Error "Failed to read credentials file: $_"
    }
} else {
    Write-Host "Credentials file not found. Creating new service principal..." -ForegroundColor Yellow
    
    # Check if user is logged in to Azure
    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context.Account) {
            Write-Host "You need to log in to Azure first. Running Connect-AzAccount..." -ForegroundColor Cyan
            Connect-AzAccount
        }
    }
    catch {
        Write-Host "You need to log in to Azure first. Running Connect-AzAccount..." -ForegroundColor Cyan
        Connect-AzAccount
    }
    
    # Get subscription - try Out-GridView first, fall back to console selection if not available
    try {
        $subscription = Get-AzSubscription | Out-GridView -Title "Select Azure Subscription" -OutputMode Single -ErrorAction Stop
    }
    catch {
        $subscriptions = Get-AzSubscription
        if ($subscriptions.Count -eq 0) {
            Write-Error "No Azure subscriptions found. Exiting."
            return
        } elseif ($subscriptions.Count -eq 1) {
            $subscription = $subscriptions[0]
            Write-Host "Using the only available subscription: $($subscription.Name)" -ForegroundColor Cyan
        } else {
            Write-Host "Available subscriptions:" -ForegroundColor Cyan
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                Write-Host "[$i] $($subscriptions[$i].Name) (ID: $($subscriptions[$i].Id))" -ForegroundColor Cyan
            }
            
            $selection = Read-Host "Enter the number of the subscription to use"
            $subscription = $subscriptions[$selection]
        }
    }
    
    if (-not $subscription) {
        Write-Error "No subscription selected. Exiting."
        return
    }
    
    # Set subscription context
    Set-AzContext -SubscriptionId $subscription.Id
    
    # Create a random name for the service principal
    $appName = "sp-azure-iac-" + (Get-Random -Minimum 100000 -Maximum 999999)
    
    # Create service principal with a random password
    Write-Host "Creating service principal $appName..." -ForegroundColor Cyan
    $sp = New-AzADServicePrincipal -DisplayName $appName -Role "Contributor" -Scope "/subscriptions/$($subscription.Id)"
    
    # Get the password
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sp.Secret))
    
    # Wait a moment for the service principal to propagate
    Start-Sleep -Seconds 15
    
    # Get the tenant ID
    $tenantId = (Get-AzContext).Tenant.Id
    
    # Prepare credentials object
    $credentials = @{
        clientId = $sp.ApplicationId
        clientSecret = $password
        subscriptionId = $subscription.Id
        tenantId = $tenantId
    }
    
    # Save to file
    $credentials | ConvertTo-Json | Set-Content -Path $credentialsFile
    
    # Set environment variables
    $env:AZURE_CLIENT_ID = $credentials.clientId
    $env:AZURE_CLIENT_SECRET = $credentials.clientSecret
    $env:AZURE_SUBSCRIPTION_ID = $credentials.subscriptionId
    $env:AZURE_TENANT_ID = $credentials.tenantId
    
    Write-Host "Service principal created and credentials saved to $credentialsFile" -ForegroundColor Green
    Write-Host "Azure credentials have been set as environment variables for the current session." -ForegroundColor Green
}

# Instructions for using these environment variables
Write-Host ""
Write-Host "To use these credentials in your scripts, replace hardcoded values with:" -ForegroundColor Cyan
Write-Host '  $clientId = $env:AZURE_CLIENT_ID' -ForegroundColor Yellow
Write-Host '  $clientSecret = $env:AZURE_CLIENT_SECRET' -ForegroundColor Yellow 
Write-Host '  $subscriptionId = $env:AZURE_SUBSCRIPTION_ID' -ForegroundColor Yellow
Write-Host '  $tenantId = $env:AZURE_TENANT_ID' -ForegroundColor Yellow
Write-Host ""
Write-Host "SECURITY NOTE: Environment variables only last for the current PowerShell session." -ForegroundColor Red
Write-Host "SECURITY WARNING: The credentials file contains secrets. Do not commit it to source control." -ForegroundColor Red 