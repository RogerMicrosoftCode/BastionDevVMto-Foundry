# Quick Start Guide

This guide provides quick commands to get started with the BastionDevVM to Azure AI Foundry migration.

## Prerequisites

- Azure CLI: `curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`
- Login: `az login`
- Set subscription: `az account set --subscription <subscription-id>`

## Quick Deployment

### Deploy Development Environment

```bash
# Create resource group
az group create --name rg-foundry-dev --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-foundry-dev \
  --template-file infra/main.bicep \
  --parameters infra/main.dev.bicepparam
```

### Deploy Production Environment

```bash
# Create resource group
az group create --name rg-foundry-prod --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-foundry-prod \
  --template-file infra/main.bicep \
  --parameters infra/main.prod.bicepparam
```

## Validation

### Validate Templates Locally

```bash
# Validate main template
az bicep build --file infra/main.bicep

# Validate all modules
for file in modules/*.bicep; do
  az bicep build --file "$file"
done
```

### What-If Deployment

Preview changes before deploying:

```bash
az deployment group what-if \
  --resource-group rg-foundry-dev \
  --template-file infra/main.bicep \
  --parameters infra/main.dev.bicepparam
```

## Post-Deployment Tasks

### Get Deployment Outputs

```bash
az deployment group show \
  --name <deployment-name> \
  --resource-group rg-foundry-dev \
  --query properties.outputs
```

### Assign User Permissions

```bash
# Get the Foundry workspace name
FOUNDRY_NAME=$(az ml workspace list \
  --resource-group rg-foundry-dev \
  --query "[0].name" -o tsv)

# Assign AI Developer role
az role assignment create \
  --assignee user@example.com \
  --role "Azure AI Developer" \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-foundry-dev/providers/Microsoft.MachineLearningServices/workspaces/${FOUNDRY_NAME}
```

### Access AI Foundry Portal

1. Navigate to: https://ai.azure.com/
2. Sign in with your Azure credentials
3. Select your Foundry hub from the dropdown

## Data Migration

### Copy Data from Old Storage

```bash
# Install azcopy if not already installed
cd ~ && wget https://aka.ms/downloadazcopy-v10-linux
tar -xvf downloadazcopy-v10-linux
sudo cp ./azcopy_linux_amd64_*/azcopy /usr/bin/

# Copy data
azcopy copy \
  'https://<old-storage>.blob.core.windows.net/<container>/*?<sas-token>' \
  'https://<new-storage>.blob.core.windows.net/foundry-data/?<sas-token>' \
  --recursive
```

## Monitoring

### View Logs

```bash
# Get Application Insights app ID
APP_ID=$(az monitor app-insights component show \
  --resource-group rg-foundry-dev \
  --app ${FOUNDRY_NAME}-insights \
  --query appId -o tsv)

# Query logs
az monitor app-insights query \
  --app ${APP_ID} \
  --analytics-query "requests | take 10"
```

### Cost Analysis

```bash
# View current month costs
az consumption usage list \
  --start-date $(date -d "$(date +%Y-%m-01)" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?resourceGroup=='rg-foundry-dev']" \
  --output table
```

## Cleanup

### Delete Environment

```bash
# Delete entire resource group (careful!)
az group delete --name rg-foundry-dev --yes --no-wait
```

## Troubleshooting

### Common Issues

**Issue: Deployment fails with "ResourceGroupNotFound"**
```bash
# Ensure resource group exists
az group create --name rg-foundry-dev --location eastus
```

**Issue: "Insufficient permissions"**
```bash
# Check your role assignment
az role assignment list --assignee <your-email> --all
```

**Issue: Private endpoint DNS not resolving**
```bash
# Verify private DNS zone is linked to VNet
az network private-dns link vnet list \
  --resource-group rg-foundry-prod \
  --zone-name privatelink.blob.core.windows.net
```

## Useful Commands

### List All Resources

```bash
az resource list \
  --resource-group rg-foundry-dev \
  --output table
```

### Get Storage Account Keys

```bash
az storage account keys list \
  --resource-group rg-foundry-dev \
  --account-name <storage-account-name>
```

### Get Key Vault Secrets

```bash
az keyvault secret list \
  --vault-name <keyvault-name>
```

### Update Tags

```bash
az group update \
  --name rg-foundry-dev \
  --tags Environment=dev CostCenter=12345
```

## Next Steps

1. Configure CI/CD with GitHub Actions (see `.github/workflows/deploy-infrastructure.yml`)
2. Set up monitoring alerts in Azure Monitor
3. Configure backup policies for critical data
4. Review and adjust network security rules
5. Implement cost management policies

For more details, see the main [README.md](README.md).
