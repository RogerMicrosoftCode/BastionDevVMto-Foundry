# BastionDevVMto-Foundry
BastionDevVMto Foundry

# 🔐 Recomendación Ejecutiva: VM Privada + Azure Bastion para Foundry

## 🎯 Arquitectura Recomendada

```
Internet ❌
    ↓
Azure Bastion (acceso seguro vía portal)
    ↓
VM Windows/Linux (tu código Python)
    ↓
Private Endpoint → Azure AI Foundry
    ↓
Managed VNet (Foundry) → OpenAI, Storage, etc.
```

---

## 📋 Checklist de Implementación

### 1️⃣ **Crear VNet Segura**
```
VNet: "vnet-foundry-dev"
├── Subnet 1: "AzureBastionSubnet" (mínimo /26)
│   └── Para Azure Bastion (nombre OBLIGATORIO)
├── Subnet 2: "snet-vm-dev" (ej: /24)
│   └── Para tu VM de desarrollo
└── Subnet 3: "snet-privatelink" (ej: /24)
    └── Para Private Endpoints de Foundry
```

**Configuración de seguridad VNet:**
- ✅ **No configurar** salida a Internet en NSG
- ✅ Denegar regla de salida por defecto
- ✅ Permitir solo comunicación interna

### 2️⃣ **Crear VM de Desarrollo**
```
Tipo: Standard_D4s_v3 o superior
OS: Windows 11 o Ubuntu 22.04
Disk: 128 GB Premium SSD
IP Pública: NINGUNA ❌
```

**Configuración de seguridad VM:**
- ✅ **Managed Identity**: System-assigned (ON)
- ✅ **No public IP**
- ✅ NSG: Solo permitir entrada desde AzureBastionSubnet
- ✅ Instalar: Python, VS Code, Azure CLI

**Roles para VM Managed Identity:**
- `Cognitive Services OpenAI User`
- `Storage Blob Data Reader`
- `Azure AI User` (en el proyecto Foundry)

### 3️⃣ **Crear Azure Bastion**
```
SKU: Standard (soporta copy/paste, file transfer)
VNet: vnet-foundry-dev
Subnet: AzureBastionSubnet
IP Pública: Crear nueva (solo para Bastion)
```

**Características habilitadas:**
- ✅ Copy/Paste
- ✅ File Upload
- ✅ Shareable Link (opcional, para otros usuarios)

### 4️⃣ **Configurar Foundry Managed Network**

**En Azure AI Foundry Hub:**
```bash
Settings → Networking → Managed Network Isolation:
- Mode: "Allow Internet Outbound"
  o mejor: "Allow Only Approved Outbound"
  
Private Endpoints (crear):
✅ Azure OpenAI
✅ Storage Account  
✅ Key Vault
✅ Azure AI Search (si aplica)

Connection en VNet:
✅ Agregar tu vnet-foundry-dev
✅ Agregar subnet snet-privatelink
```

### 5️⃣ **Crear Private Endpoint para Foundry**
```
Resource: Tu Azure AI Foundry Hub
Target sub-resource: aistudio
VNet: vnet-foundry-dev
Subnet: snet-privatelink
Private DNS: Sí (automático)
```

---

## 🔧 Configuración NSG Crítica

### NSG para `snet-vm-dev`:
```yaml
Inbound:
- Priority 100: Allow from AzureBastionSubnet → VM (3389/RDP o 22/SSH)
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to VirtualNetwork → 443 (HTTPS)
- Priority 110: Allow to AzureCloud → 443 (Azure APIs)
- Priority 4096: Deny Internet ❌
```

### NSG para `AzureBastionSubnet`:
```yaml
Inbound:
- Priority 100: Allow GatewayManager → 443
- Priority 110: Allow Internet → 443 (portal)
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to VirtualNetwork → 3389, 22
- Priority 110: Allow to AzureCloud → 443
```

---

## ⚡ Quick Start (Orden de Ejecución)

```bash
1. Crear Resource Group
   └─ rg-foundry-secure-dev

2. Crear VNet con 3 subnets
   └─ AzureBastionSubnet (/26)
   └─ snet-vm-dev (/24)
   └─ snet-privatelink (/24)

3. Crear NSGs y aplicar a subnets

4. Crear VM (sin IP pública)
   └─ Enable Managed Identity

5. Crear Azure Bastion (SKU Standard)

6. En Foundry Hub:
   └─ Enable Managed Network
   └─ Create Private Endpoints

7. Crear Private Endpoint de Foundry en tu VNet

8. Asignar roles RBAC a VM Managed Identity

9. Conectar vía Bastion → Instalar herramientas

10. Probar conexión Python desde VM
```

---

## 🧪 Script de Prueba en VM

```python
# test_foundry_private.py
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient

# Managed Identity se autentica automáticamente
credential = DefaultAzureCredential()

project = AIProjectClient.from_connection_string(
    credential=credential,
    conn_str="tu_connection_string"
)

agent = project.agents.get_agent("tu_agent_id")
print(f"✅ Conexión privada exitosa: {agent.name}")
```

---

## 🔒 Validaciones de Seguridad

**Checklist final:**
- [ ] VM no tiene IP pública
- [ ] No hay Internet outbound desde VM (excepto Azure services)
- [ ] Bastion es el ÚNICO punto de entrada
- [ ] Private Endpoints configurados para Foundry
- [ ] NSGs aplicados correctamente
- [ ] Managed Identity habilitada en VM
- [ ] Roles RBAC asignados
- [ ] DNS privado resuelve correctamente


---

## 📚 Documentación Oficial

- **Managed Network**: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-managed-network
- **Azure Bastion**: https://learn.microsoft.com/en-us/azure/bastion/bastion-overview
- **Private Link Foundry**: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link

---

## 🎯 Resumen Ultra-Ejecutivo

**3 Pasos Críticos:**
1. ✅ VNet con 3 subnets + NSGs restrictivos
2. ✅ VM sin IP pública + Azure Bastion Standard
3. ✅ Foundry Managed Network + Private Endpoints

**Tiempo estimado:** 2-3 horas  
**Seguridad:** Zero Trust compliant ✅

---

## 📝 Notas Adicionales

- Azure Bastion elimina la necesidad de VPN o ExpressRoute para acceso administrativo
- La VM usa Managed Identity, eliminando la necesidad de almacenar credenciales
- Todos los servicios de Azure se comunican vía Private Endpoints sin salir a Internet público
- Esta configuración cumple con requisitos de Zero Trust y normativas de seguridad empresarial

---


---

**Versión:** 1.0  
**Fecha:** Noviembre 2025  
**Autor:** Equipo de Arquitectura Cloud
