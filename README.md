# BastionDevVM to Azure AI Foundry Migration

This repository contains Infrastructure as Code (IaC) using Bicep templates to migrate from an Azure Bastion DevVM setup to Azure AI Foundry.

## Overview

Azure AI Foundry represents a unified, API-first approach for developing and managing AI projects, agents, and models. This migration streamlines your development environment by consolidating resources and improving security through managed networking and private endpoints.

## Architecture

The infrastructure includes:

- **Azure AI Foundry Hub**: Central hub for AI development and model management
- **Cognitive Services**: AI Services for various AI capabilities
- **Storage Account**: Secure blob storage for AI data and models
- **Key Vault**: Secrets and key management
- **Virtual Network**: Isolated network with subnets for services and private endpoints
- **Network Security Groups**: Security rules for network traffic control
- **Application Insights & Log Analytics**: Monitoring and logging

### Network Architecture

- **VNet**: Virtual network with configurable address space
- **Foundry Subnet**: Dedicated subnet for AI Foundry resources
- **Private Endpoint Subnet**: Subnet for private endpoints (production)
- **NSGs**: Network security groups with least-privilege access rules

## Prerequisites

- Azure subscription
- Azure CLI installed and authenticated
- Bicep CLI (included with Azure CLI)
- Appropriate Azure RBAC permissions (Contributor or Owner on subscription/resource group)

For GitHub Actions deployment:
- Azure service principal with federated credentials
- GitHub repository secrets configured (see Setup section)

## Repository Structure

```
.
├── infra/
│   ├── main.bicep                    # Main orchestrator template
│   ├── main.dev.bicepparam           # Development environment parameters
│   └── main.prod.bicepparam          # Production environment parameters
├── modules/
│   ├── networking.bicep              # Virtual network and subnets
│   ├── storage.bicep                 # Storage account with private endpoint
│   ├── keyvault.bicep                # Key Vault with private endpoint
│   └── ai-foundry.bicep              # AI Foundry Hub and services
├── .github/
│   └── workflows/
│       └── deploy-infrastructure.yml # GitHub Actions deployment workflow
└── README.md
```

## Deployment Options

### Option 1: Manual Deployment with Azure CLI

#### Development Environment

```bash
# Login to Azure
az login

# Create resource group
az group create \
  --name rg-foundry-dev \
  --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-foundry-dev \
  --template-file infra/main.bicep \
  --parameters infra/main.dev.bicepparam
```

#### Production Environment

```bash
# Create resource group
az group create \
  --name rg-foundry-prod \
  --location eastus

# Deploy infrastructure with private endpoints
az deployment group create \
  --resource-group rg-foundry-prod \
  --template-file infra/main.bicep \
  --parameters infra/main.prod.bicepparam
```

### Option 2: GitHub Actions Deployment

#### Setup

1. Create an Azure Service Principal with federated credentials:

```bash
# Create service principal
az ad sp create-for-rbac \
  --name "sp-foundry-deployment" \
  --role contributor \
  --scopes /subscriptions/{subscription-id}

# Configure federated credentials for GitHub Actions
az ad app federated-credential create \
  --id {app-id} \
  --parameters '{
    "name": "github-foundry-deployment",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:{your-org}/{your-repo}:ref:refs/heads/main",
    "description": "GitHub Actions deployment",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

2. Configure GitHub repository secrets:
   - `AZURE_CLIENT_ID`: Application (client) ID
   - `AZURE_TENANT_ID`: Directory (tenant) ID
   - `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

3. Run the workflow:
   - Go to Actions tab in GitHub
   - Select "Deploy Azure AI Foundry Infrastructure"
   - Click "Run workflow"
   - Choose environment and provide resource group name

## Configuration

### Parameters

Key parameters that can be customized in `.bicepparam` files:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `foundryName` | Name of the AI Foundry hub | `foundry-dev` |
| `environment` | Environment (dev/test/prod) | `dev` |
| `enablePrivateEndpoints` | Enable private endpoints | `false` (dev), `true` (prod) |
| `vnetAddressPrefix` | VNet address space | `10.0.0.0/16` |
| `foundrySubnetPrefix` | Foundry subnet CIDR | `10.0.1.0/24` |
| `privateEndpointSubnetPrefix` | Private endpoint subnet CIDR | `10.0.2.0/24` |

### Environment Differences

**Development (`dev`)**:
- Public network access enabled
- Standard SKUs
- Lower cost options
- Simplified networking

**Production (`prod`)**:
- Private endpoints enabled
- Network isolation
- Enhanced security
- Managed network with approved outbound rules

## Post-Deployment

### Verify Deployment

```bash
# List deployed resources
az resource list \
  --resource-group rg-foundry-prod \
  --output table

# Get deployment outputs
az deployment group show \
  --name {deployment-name} \
  --resource-group rg-foundry-prod \
  --query properties.outputs
```

### Access AI Foundry

1. Navigate to [Azure AI Foundry](https://ai.azure.com/)
2. Sign in with your Azure credentials
3. Select your deployed Foundry hub
4. Start creating projects and deploying models

### Configure RBAC

Grant users access to the AI Foundry hub:

```bash
# Assign AI Developer role
az role assignment create \
  --assignee {user-email} \
  --role "Azure AI Developer" \
  --scope /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.MachineLearningServices/workspaces/{foundry-name}
```

## Migration Guide

### From Bastion DevVM

1. **Inventory Current Resources**:
   - List all VMs, storage accounts, and networking components
   - Document agent configurations and data stores
   - Export any custom scripts or configurations

2. **Deploy New Infrastructure**:
   - Use this repository to deploy the Foundry infrastructure
   - Start with development environment for testing

3. **Migrate Data**:
   - Copy data from old storage to new storage account
   - Use `azcopy` for efficient large-scale data transfer

4. **Migrate Agents and Models**:
   - Re-create agents in Foundry projects
   - Update connection strings and endpoints
   - Test thoroughly in development environment

5. **Update Applications**:
   - Update SDK references to latest versions
   - Change authentication to use managed identities
   - Update endpoint URLs to Foundry endpoints

6. **Cutover**:
   - Deploy production infrastructure
   - Perform final data sync
   - Update DNS/routing if applicable
   - Decommission old DevVM infrastructure

## Monitoring and Management

### Application Insights

Monitor your AI Foundry hub:
- Navigate to Application Insights resource in Azure Portal
- View metrics, logs, and performance data
- Set up alerts for critical events

### Cost Management

Track spending:
```bash
# View costs by resource group
az consumption usage list \
  --start-date 2025-01-01 \
  --end-date 2025-01-31 \
  --query "[?resourceGroup=='rg-foundry-prod']"
```

## Security Considerations

- **Managed Identities**: All services use system-assigned managed identities
- **RBAC**: Role-based access control configured for all resources
- **Private Endpoints**: Production uses private endpoints for network isolation
- **Encryption**: All data encrypted at rest and in transit
- **Key Vault**: Secrets stored securely in Key Vault
- **Network Security**: NSGs restrict traffic to necessary ports only

## Troubleshooting

### Common Issues

**Deployment Failures**:
- Verify Azure CLI is logged in: `az account show`
- Check RBAC permissions on subscription/resource group
- Validate parameter files syntax

**Private Endpoint Connectivity**:
- Ensure DNS resolution is configured
- Verify NSG rules allow required traffic
- Check private DNS zones are linked to VNet

**Storage Access Issues**:
- Confirm managed identity has Storage Blob Data Contributor role
- Verify network rules if using private endpoints

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Resources

- [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-foundry/)
- [Migrate from Hub to Foundry](https://learn.microsoft.com/azure/ai-foundry/how-to/migrate-project)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure AI Foundry Samples](https://github.com/Azure-Samples/azure-ai-foundry-samples)

## License

MIT License - See LICENSE file for details
