# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                        │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Resource Group                           │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Virtual Network (10.0.0.0/16)            │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌──────────────────────────────────────────────┐    │  │ │
│  │  │  │   Foundry Subnet (10.0.1.0/24)                │    │  │ │
│  │  │  │   - Service Endpoints enabled                 │    │  │ │
│  │  │  │   - NSG attached                               │    │  │ │
│  │  │  └──────────────────────────────────────────────┘    │  │ │
│  │  │                                                        │  │ │
│  │  │  ┌──────────────────────────────────────────────┐    │  │ │
│  │  │  │   Private Endpoint Subnet (10.0.2.0/24)       │    │  │ │
│  │  │  │   - Private Endpoints for Storage/KeyVault    │    │  │ │
│  │  │  │   - NSG attached                               │    │  │ │
│  │  │  └──────────────────────────────────────────────┘    │  │ │
│  │  │                                                        │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │ │
│  │  │   AI Foundry  │  │   Cognitive  │  │ Application  │    │ │
│  │  │      Hub      │  │   Services   │  │   Insights   │    │ │
│  │  │  (ML Workspace)│  │  (AI Services)│  │              │    │ │
│  │  └───────┬───────┘  └──────┬───────┘  └──────┬───────┘    │ │
│  │          │                  │                  │            │ │
│  │          │                  │                  │            │ │
│  │          ├──────────────────┴──────────────────┤            │ │
│  │          │                                      │            │ │
│  │  ┌───────▼────────┐                   ┌────────▼────────┐  │ │
│  │  │  Storage Account│                   │  Log Analytics  │  │ │
│  │  │  - Blob Storage │                   │    Workspace    │  │ │
│  │  │  - Private Link │                   │                 │  │ │
│  │  └────────────────┘                   └─────────────────┘  │ │
│  │                                                              │ │
│  │  ┌──────────────┐                                          │ │
│  │  │  Key Vault   │                                          │ │
│  │  │ - Secrets    │                                          │ │
│  │  │ - Private Link│                                          │ │
│  │  └──────────────┘                                          │ │
│  │                                                              │ │
│  │  ┌──────────────────────────────────────────────────────┐  │ │
│  │  │              Private DNS Zones                        │  │ │
│  │  │  - privatelink.blob.core.windows.net                 │  │ │
│  │  │  - privatelink.vaultcore.azure.net                   │  │ │
│  │  └──────────────────────────────────────────────────────┘  │ │
│  │                                                              │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Component Details

### AI Foundry Hub (Machine Learning Workspace)
- **Type**: Hub workspace for AI development
- **Purpose**: Central hub for managing AI projects, models, and experiments
- **Features**:
  - Project management
  - Model registry
  - Experiment tracking
  - Managed compute
  - Integration with Cognitive Services

### Cognitive Services (AI Services)
- **Type**: Multi-service AI resource
- **Purpose**: Provides various AI capabilities
- **Capabilities**:
  - Language understanding
  - Vision processing
  - Speech services
  - Decision making
- **Authentication**: Managed Identity (System-assigned)

### Storage Account
- **Type**: Azure Blob Storage (StorageV2)
- **Purpose**: Store AI data, models, and artifacts
- **Security**:
  - Private endpoint (production)
  - Service endpoints (development)
  - Encryption at rest
  - TLS 1.2 minimum
- **Access Control**: RBAC with managed identities

### Key Vault
- **Type**: Azure Key Vault (Standard SKU)
- **Purpose**: Secure storage for secrets and keys
- **Security**:
  - Private endpoint (production)
  - RBAC authorization
  - Soft delete enabled (90 days)
  - Purge protection
- **Features**:
  - Secret management
  - Key management
  - Certificate management

### Virtual Network
- **Address Space**: Configurable (default: 10.0.0.0/16)
- **Subnets**:
  1. **Foundry Subnet**: Hosts AI Foundry resources
  2. **Private Endpoint Subnet**: Hosts private endpoints
- **Security**: Network Security Groups on each subnet

### Network Security Groups (NSGs)
- **Foundry NSG**:
  - Allow HTTPS (443) from VNet
  - Deny all other inbound traffic
- **Private Endpoint NSG**:
  - Minimal rules (private endpoints manage their own traffic)

### Application Insights
- **Type**: Application Performance Management
- **Purpose**: Monitor AI Foundry operations
- **Features**:
  - Real-time metrics
  - Application map
  - Failed request tracking
  - Custom events
- **Integration**: Linked to Log Analytics workspace

### Log Analytics Workspace
- **Purpose**: Centralized logging and analytics
- **Retention**: 30 days (configurable)
- **Integration**: Application Insights backend

## Security Architecture

### Identity and Access Management

```
┌─────────────────────────────────────────────────────┐
│              Azure Active Directory (Entra ID)       │
│                                                       │
│  ┌────────────────┐  ┌─────────────────────────┐   │
│  │  User Identity  │  │  Managed Identities     │   │
│  │                 │  │  - AI Foundry Hub       │   │
│  │  RBAC Roles:    │  │  - Cognitive Services   │   │
│  │  - AI Developer │  │                         │   │
│  │  - Contributor  │  │  RBAC Assignments:      │   │
│  │  - Reader       │  │  - Storage Contributor  │   │
│  └────────────────┘  └─────────────────────────┘   │
└─────────────────────────────────────────────────────┘
                    │
                    │ Authentication & Authorization
                    ▼
┌─────────────────────────────────────────────────────┐
│              Azure Resources                         │
│  - AI Foundry Hub                                    │
│  - Cognitive Services                                │
│  - Storage Account                                   │
│  - Key Vault                                         │
└─────────────────────────────────────────────────────┘
```

### Network Security

#### Development Environment
- Public endpoints enabled
- Service endpoints for VNet integration
- NSG rules for basic protection
- Suitable for development and testing

#### Production Environment
- Private endpoints for all services
- No public internet access
- Private DNS zones for name resolution
- Full network isolation
- VNet integration required

### Data Flow

```
User/Application
      │
      │ HTTPS
      ▼
┌──────────────────┐
│  AI Foundry Hub  │
│   (Public/PE)    │
└────────┬─────────┘
         │
         ├──────────────┬────────────────┐
         │              │                │
         ▼              ▼                ▼
┌────────────┐  ┌──────────────┐  ┌──────────┐
│  Cognitive │  │   Storage    │  │ Key Vault│
│  Services  │  │   Account    │  │          │
│  (Private) │  │  (Private)   │  │(Private) │
└────────────┘  └──────────────┘  └──────────┘
         │              │                │
         │              │                │
         └──────┬───────┴────────────────┘
                │
                │ Logs & Metrics
                ▼
┌──────────────────────────────────────┐
│      Application Insights             │
│      Log Analytics Workspace          │
└──────────────────────────────────────┘
```

## Deployment Architecture

### Infrastructure as Code

```
┌─────────────────────────────────────────────┐
│           GitHub Repository                  │
│                                               │
│  ┌─────────────────────────────────────┐   │
│  │  Bicep Templates                     │   │
│  │  - main.bicep (orchestrator)        │   │
│  │  - modules/*.bicep (components)     │   │
│  │  - *.bicepparam (parameters)        │   │
│  └──────────────┬──────────────────────┘   │
│                 │                            │
│  ┌──────────────▼──────────────────────┐   │
│  │  GitHub Actions                      │   │
│  │  - validate-bicep.yml                │   │
│  │  - deploy-infrastructure.yml         │   │
│  └──────────────┬──────────────────────┘   │
└─────────────────┼──────────────────────────┘
                  │
                  │ Deploy
                  ▼
┌─────────────────────────────────────────────┐
│          Azure Resource Manager              │
│                                               │
│  ┌──────────────────────────────────────┐   │
│  │  Deployment Validation                │   │
│  │  - Template validation                │   │
│  │  - What-if analysis                   │   │
│  └──────────────┬───────────────────────┘   │
│                 │                             │
│  ┌──────────────▼───────────────────────┐   │
│  │  Resource Provisioning               │   │
│  │  - Network resources                  │   │
│  │  - Storage & Key Vault               │   │
│  │  - AI Foundry & Services             │   │
│  │  - RBAC assignments                  │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

## Scalability Considerations

### Compute Scaling
- AI Foundry supports managed compute clusters
- Auto-scaling based on workload
- Multiple node types available

### Storage Scaling
- Blob storage scales automatically
- Consider premium storage for high IOPS
- Lifecycle management for cost optimization

### Network Scaling
- VNet supports up to 65,536 IPs
- Can peer with other VNets
- Multiple subnets for workload isolation

## Disaster Recovery

### Backup Strategy
- Storage Account: Geo-redundant storage (GRS)
- Key Vault: Soft delete + purge protection
- AI models: Version control in model registry

### Recovery Objectives
- **RTO**: Recovery Time Objective
  - Dev: 24 hours
  - Prod: 4 hours
- **RPO**: Recovery Point Objective
  - Dev: 24 hours
  - Prod: 1 hour

## Monitoring and Observability

### Metrics Collected
- AI Foundry operations
- API request counts
- Error rates
- Latency
- Storage usage
- Key Vault access

### Alerts Configured
- Failed deployments
- High error rates
- Quota limits
- Security violations

## Cost Optimization

### Cost Factors
1. **Compute**: AI Foundry compute clusters
2. **Storage**: Blob storage (Hot tier)
3. **Cognitive Services**: Per-transaction pricing
4. **Networking**: Data egress
5. **Monitoring**: Log Analytics ingestion

### Cost Reduction Strategies
- Use reserved instances for predictable workloads
- Implement lifecycle policies for storage
- Right-size compute resources
- Use budget alerts
- Tag resources for cost tracking

## Compliance and Governance

### Azure Policies
- Enforce tagging
- Require encryption
- Restrict public access
- Mandate private endpoints

### Compliance Standards
- SOC 2
- ISO 27001
- HIPAA (with additional configuration)
- GDPR

## Migration Path

### Phase 1: Assessment
- Inventory existing resources
- Identify dependencies
- Plan network architecture

### Phase 2: Pilot
- Deploy dev environment
- Test with sample workloads
- Validate connectivity

### Phase 3: Migration
- Deploy production infrastructure
- Migrate data and models
- Update applications
- Cutover

### Phase 4: Optimization
- Performance tuning
- Cost optimization
- Security hardening
- Documentation

## References

- [Azure AI Foundry Documentation](https://learn.microsoft.com/azure/ai-foundry/)
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
