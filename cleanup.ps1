# Cleanup script for Azure resources
# Quinten De Meyer (QDM)

# Parameters
$resourceGroupName = "qdm-flask-crud-rg"

# Login to Azure
Connect-AzAccount

# Confirm deletion
$confirmation = Read-Host "Are you sure you want to delete all resources in resource group $resourceGroupName? (y/n)"

if ($confirmation -eq 'y') {
    Write-Host "Deleting resource group $resourceGroupName..."
    Remove-AzResourceGroup -Name $resourceGroupName -Force
    Write-Host "Resource group deleted successfully."
} else {
    Write-Host "Deletion cancelled."
} 