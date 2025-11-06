# Contributing to BastionDevVM to Foundry Migration

Thank you for your interest in contributing to this project! This document provides guidelines and instructions for contributing.

## Development Setup

### Prerequisites

1. Install Azure CLI:
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. Install Bicep CLI (included with Azure CLI):
   ```bash
   az bicep install
   ```

3. Login to Azure:
   ```bash
   az login
   ```

### Repository Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR-USERNAME/BastionDevVMto-Foundry.git
   cd BastionDevVMto-Foundry
   ```

3. Add upstream remote:
   ```bash
   git remote add upstream https://github.com/RogerMicrosoftCode/BastionDevVMto-Foundry.git
   ```

## Making Changes

### Bicep Template Guidelines

1. **Modular Design**: Keep modules focused and reusable
2. **Parameters**: Use descriptive names with proper descriptions
3. **Naming Conventions**: Follow Azure naming best practices
4. **Comments**: Add comments for complex logic
5. **Security**: Always use secure defaults (private endpoints, RBAC, etc.)

### Template Structure

```
.
├── infra/              # Main orchestrator templates
├── modules/            # Reusable Bicep modules
├── .github/workflows/  # CI/CD workflows
└── docs/              # Additional documentation
```

### Coding Standards

1. **Indentation**: Use 2 spaces (Bicep standard)
2. **Line Length**: Keep lines under 120 characters when possible
3. **Resource Naming**: Use consistent naming patterns
4. **Tags**: Include environment and project tags

Example:
```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags  // Always include tags parameter
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'  // Security best practice
    supportsHttpsTrafficOnly: true
  }
}
```

## Validation

### Validate Templates Before Committing

```bash
# Validate main template
az bicep build --file infra/main.bicep

# Validate all modules
for file in modules/*.bicep; do
  az bicep build --file "$file"
done
```

### Test Deployment

Always test in a dev environment before submitting:

```bash
az deployment group create \
  --resource-group rg-test \
  --template-file infra/main.bicep \
  --parameters infra/main.dev.bicepparam \
  --what-if
```

## Submitting Changes

### Pull Request Process

1. **Create a Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**: Follow the coding standards

3. **Validate**: Run validation commands

4. **Commit**: Write clear commit messages
   ```bash
   git commit -m "Add: Brief description of change"
   ```
   
   Commit message prefixes:
   - `Add:` New feature or resource
   - `Fix:` Bug fix
   - `Update:` Update existing feature
   - `Refactor:` Code restructuring
   - `Docs:` Documentation changes

5. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open Pull Request**: 
   - Go to GitHub and create a PR
   - Fill out the PR template
   - Link any related issues

### Pull Request Guidelines

- **Title**: Clear and descriptive
- **Description**: Explain what and why
- **Testing**: Document testing performed
- **Screenshots**: Include if UI/Portal changes
- **Breaking Changes**: Clearly mark any breaking changes

## Code Review

### Review Criteria

1. **Functionality**: Does it work as intended?
2. **Security**: Are security best practices followed?
3. **Performance**: Is it efficient?
4. **Documentation**: Is it well documented?
5. **Tests**: Are changes validated?

### Addressing Feedback

- Be responsive to comments
- Make requested changes in new commits
- Don't force-push until review is complete

## Adding New Modules

When adding new Bicep modules:

1. Create module in `modules/` directory
2. Add proper parameter documentation
3. Include example usage in comments
4. Update main.bicep to reference new module
5. Create/update parameter files
6. Update README.md
7. Test thoroughly

Example module structure:

```bicep
// Module: Resource Name
targetScope = 'resourceGroup'

@description('Required parameter description')
param requiredParam string

@description('Optional parameter description')
param optionalParam string = 'default-value'

// Resource definitions...

// Outputs
output resourceId string = resource.id
output resourceName string = resource.name
```

## Documentation

### When to Update Documentation

- Adding new features
- Changing existing behavior
- Adding new parameters
- Updating workflows
- Adding examples

### Documentation Files

- **README.md**: Main project documentation
- **QUICKSTART.md**: Quick reference guide
- **CONTRIBUTING.md**: This file
- Inline comments in Bicep files

## GitHub Actions

### Workflow Validation

All workflows must:
- Use explicit permissions
- Include error handling
- Have clear step names
- Use latest action versions

### Adding New Workflows

1. Create workflow in `.github/workflows/`
2. Add proper permissions block
3. Test workflow in your fork
4. Document workflow purpose

## Security

### Security Guidelines

1. **Never commit secrets**: Use Azure Key Vault
2. **Use RBAC**: Implement least-privilege access
3. **Private Endpoints**: Use in production
4. **Encryption**: Enable encryption at rest and in transit
5. **TLS**: Require TLS 1.2 minimum
6. **Network Rules**: Implement proper NSG rules

### Reporting Security Issues

If you discover a security vulnerability:
1. **Do NOT** open a public issue
2. Email the maintainers directly
3. Provide detailed description
4. Allow time for fix before disclosure

## Community

### Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Provide constructive feedback
- Focus on what is best for the community

### Getting Help

- Check existing issues
- Review documentation
- Ask in discussions
- Tag maintainers if needed

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

If you have questions about contributing, please:
1. Check existing documentation
2. Search closed issues
3. Open a new discussion
4. Tag maintainers for urgent matters

Thank you for contributing!
