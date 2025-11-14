# Modular Bicep Template - Application Gateway + APIM + Azure Function

This repository contains a modular version of the Application Gateway + API Management + Azure Function deployment, breaking the monolithic template into reusable, organized modules.

## 📁 Project Structure

```
├── modules/
│   ├── networking/
│   │   └── vnet.bicep              # Virtual Network, subnets, NSG for APIM
│   ├── storage/
│   │   └── storage.bicep           # Storage Account with network rules
│   ├── monitoring/
│   │   └── monitoring.bicep        # Log Analytics Workspace & Application Insights
│   ├── compute/
│   │   ├── function-app.bicep      # App Service Plan & Function App
│   │   └── role-assignments.bicep  # RBAC roles for Function App
│   ├── apim/
│   │   └── apim.bicep             # API Management with backend configuration
│   └── gateway/
│       └── app-gateway.bicep      # Application Gateway with routing rules
├── main.bicep      # Main orchestration template
├── main.bicepparam # Parameters file
└── README-Modular.md                                # This documentation
```

## 🏗️ Module Architecture

### 1. Networking Module (`modules/networking/vnet.bicep`)
- **Purpose**: Network foundation and security
- **Resources**: 
  - Virtual Network with 3 subnets (App Gateway, APIM, Function App)
  - Network Security Group for APIM (follows Microsoft requirements)
  - Subnet delegations for Function App (Microsoft.App/environments)
- **Outputs**: VNet ID, subnet IDs, subnet names

### 2. Storage Module (`modules/storage/storage.bicep`)
- **Purpose**: Secure storage for Function App
- **Resources**: 
  - Storage Account with network access controls
  - VNet rules limiting access to specific subnets
- **Outputs**: Storage ID, primary endpoints

### 3. Monitoring Module (`modules/monitoring/monitoring.bicep`)
- **Purpose**: Observability and telemetry
- **Resources**: 
  - Log Analytics Workspace
  - Application Insights linked to workspace
- **Outputs**: Connection strings and resource IDs

### 4. Compute Module (`modules/compute/`)
- **function-app.bicep**: 
  - App Service Plan (Flex Consumption)
  - Function App with VNet integration
  - Managed identity configuration
- **role-assignments.bicep**: 
  - Storage Blob Data Owner role
  - Storage Queue Data Contributor role
  - Storage Table Data Contributor role

### 5. APIM Module (`modules/apim/apim.bicep`)
- **Purpose**: API management layer
- **Resources**: 
  - API Management service (Internal VNet mode)
  - Backend configuration for Function App
  - Echo API with routing policies
- **Outputs**: APIM gateway URLs for Application Gateway

### 6. Application Gateway Module (`modules/gateway/app-gateway.bicep`)
- **Purpose**: Load balancing and public access
- **Resources**: 
  - Public IP address
  - Application Gateway with HTTP listener
  - Backend pool pointing to APIM
- **Outputs**: Public IP address

## 🚀 Deployment

### Prerequisites
- Azure CLI installed and logged in
- PowerShell 7+ (for deployment script)
- Appropriate Azure permissions (Contributor or Owner)

### Manual Deploy
```bash
azd up
```

## 📋 Key Improvements Over Monolithic Template

### ✅ **Modularity**
- Each module has a single responsibility
- Modules can be reused across different projects
- Easier to test individual components

### ✅ **Maintainability**
- Changes to one component don't affect others
- Clear separation of concerns
- Easier to troubleshoot deployment issues

### ✅ **Reusability**
- Networking module can be shared across projects
- Monitoring module standardized across environments
- Function App module reusable for different workloads

### ✅ **Best Practices**
- Proper parameter validation and documentation
- Comprehensive outputs for module chaining
- Clear naming conventions and resource organization

### ✅ **Error Resolution**
- Fixed subnet delegation issue (Microsoft.App/environments)
- Added required NSG for APIM Internal VNet deployment
- Proper dependency management between modules

## 🔧 Configuration

### Network Configuration
- **VNet Address Space**: 10.1.0.0/16
- **App Gateway Subnet**: 10.1.0.0/24
- **APIM Subnet**: 10.1.1.0/24 (with NSG)
- **Function Subnet**: 10.1.2.0/24 (delegated to Microsoft.App/environments)

### Security Features
- Storage account restricted to VNet subnets only
- APIM deployed in Internal VNet mode
- Function App with managed identity
- Proper RBAC roles for storage access
- NSG rules following Microsoft APIM requirements

## 📊 Outputs
After deployment, you'll receive:
- **Application Gateway Public IP**: Entry point for external traffic
- **APIM Gateway URL**: Internal APIM endpoint
- **Function App Name**: For deployment and management
- **Virtual Network Name**: For reference and additional resources

## 🤝 Contributing
When adding new modules:
1. Follow the established naming conventions
2. Include comprehensive parameter documentation
3. Provide meaningful outputs for module chaining
4. Test modules independently before integration

---

This modular approach provides a robust, maintainable foundation for enterprise-grade Azure deployments while solving the specific issues encountered in the original deployment.
