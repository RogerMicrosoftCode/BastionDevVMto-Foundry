# 🔐 Recomendación Ejecutiva: VM Privada + Azure Bastion para Foundry

## 🎯 Arquitectura Recomendada

### Opción 1: Solo Azure Bastion (Recomendado para acceso individual)
```
Internet ❌
    ↓
Azure Bastion (acceso seguro vía portal/SSH)
    ↓
VM Windows/Linux (tu código Python)
    ↓
Private Endpoint → Azure AI Foundry
    ↓
Managed VNet (Foundry) → OpenAI, Storage, etc.
```

### Opción 2: Con VPN Gateway (Recomendado para equipos/red corporativa)
```
Red Corporativa/Local
    ↓
VPN Gateway (Site-to-Site o Point-to-Site)
    ↓
VNet Hub (vnet-foundry-hub)
    ├── GatewaySubnet
    ├── AzureBastionSubnet
    └── VNet Peering
        ↓
VNet Spoke (vnet-foundry-dev)
    ├── snet-vm-dev → VM de desarrollo
    └── snet-privatelink → Private Endpoints
        ↓
Azure AI Foundry (privado)
```

---

## 📋 Checklist de Implementación

### Escenario A: Azure Bastion + SSH (Acceso Individual)

### 1️⃣ **Crear VNet Segura (Segmentación Optimizada)**
```
VNet: "vnet-foundry-dev" (10.1.0.0/24)
├── Subnet 1: "AzureBastionSubnet" (10.1.0.0/26)
│   └── Para Azure Bastion (64 IPs, nombre OBLIGATORIO)
├── Subnet 2: "snet-vm-dev" (10.1.0.64/27)
│   └── Para VMs de desarrollo (32 IPs, hasta 27 VMs)
└── Subnet 3: "snet-privatelink" (10.1.0.96/28)
    └── Para Private Endpoints (16 IPs, hasta 11 endpoints)
```

**📏 Mejores prácticas de segmentación:**
- ✅ Usar el CIDR más pequeño posible por subnet
- ✅ AzureBastionSubnet: /26 o /27 (mínimo /26 recomendado)
- ✅ Private Endpoints: /28 (1 IP por endpoint)
- ✅ VMs pequeños equipos (1-5): /28 (16 IPs)
- ✅ VMs equipos medianos (6-20): /27 (32 IPs)
- ⚠️ Azure reserva 5 IPs por subnet

**Configuración de seguridad VNet:**
- ✅ **No configurar** salida a Internet en NSG
- ✅ Denegar regla de salida por defecto
- ✅ Permitir solo comunicación interna

---

### Escenario B: VPN Gateway + Hub-Spoke (Acceso Corporativo)

### 1️⃣ **Crear VNet Hub (Conectividad Central)**
```
VNet Hub: "vnet-foundry-hub" (10.0.0.0/24)
├── Subnet 1: "GatewaySubnet" (10.0.0.0/27)
│   └── Para VPN Gateway (32 IPs, nombre OBLIGATORIO)
├── Subnet 2: "AzureBastionSubnet" (10.0.0.32/26)
│   └── Para Azure Bastion (64 IPs, nombre OBLIGATORIO)
└── Subnet 3: "snet-firewall" (10.0.0.96/27) - Opcional
    └── Para Azure Firewall (32 IPs)
```

**📏 Dimensionamiento GatewaySubnet:**
- ✅ /27 (32 IPs) - Soporta hasta VpnGw5
- ✅ /26 (64 IPs) - Para alta disponibilidad activo-activo
- ⚠️ Mínimo absoluto: /29 (8 IPs) - No recomendado

### 2️⃣ **Crear VNet Spoke (Recursos de Desarrollo)**
```
VNet Spoke: "vnet-foundry-dev" (10.1.0.0/24)
├── Subnet 1: "snet-vm-dev" (10.1.0.0/27)
│   └── Para VMs de desarrollo (32 IPs)
├── Subnet 2: "snet-privatelink" (10.1.0.32/28)
│   └── Para Private Endpoints (16 IPs)
└── Subnet 3: "snet-containers" (10.1.0.64/26) - Opcional
    └── Para AKS o Azure Container Instances (64 IPs)
```

**📏 Dimensionamiento recomendado:**
| Componente | Tamaño Equipo | CIDR Recomendado | IPs Disponibles |
|------------|---------------|------------------|-----------------|
| VMs Dev | 1-10 usuarios | /28 | 11 |
| VMs Dev | 11-25 usuarios | /27 | 27 |


### 3️⃣ **Configurar VNet Peering**
```bash
Hub → Spoke Peering:
- Name: "hub-to-spoke"
- Allow gateway transit: ✅ YES
- Use remote gateways: ❌ NO

Spoke → Hub Peering:
- Name: "spoke-to-hub"
- Allow gateway transit: ❌ NO
- Use remote gateways: ✅ YES
```

### 4️⃣ **Crear VPN Gateway**

**Configuración VPN Gateway:**
```
Name: vpn-foundry-gateway
VNet: vnet-foundry-hub
Subnet: GatewaySubnet
Gateway Type: VPN
VPN Type: Route-based
SKU: VpnGw2 (recomendado para producción)
Generation: Generation2
Active-active mode: Disabled (o Enabled para HA)
```

**Opciones de VPN:**

#### Opción A: Point-to-Site (P2S) - Para usuarios remotos
```yaml
Address Pool: 172.16.0.0/24 (no solapar con VNets existentes)
Tunnel Type: OpenVPN (SSL) o IKEv2
Authentication: Azure Certificate o Azure AD

Características:
- ✅ Usuarios individuales desde cualquier lugar
- ✅ Cliente VPN en laptops/workstations
- ✅ Ideal para trabajo remoto
- ⚠️ Requiere configuración de certificados o Azure AD
```

#### Opción B: Site-to-Site (S2S) - Para oficina corporativa
```yaml
Local Network Gateway:
- On-premises IP: IP pública de firewall corporativo
- Address Space: Rango IP de red local (ej: 192.168.0.0/16)

Connection:
- Type: IPsec
- Shared Key: <clave-precompartida-segura>

Características:
- ✅ Toda la oficina con acceso automático
- ✅ No requiere VPN client individual
- ✅ Ideal para equipos grandes
- ⚠️ Requiere dispositivo VPN compatible en oficina
```

---

### 5️⃣ **Crear VM de Desarrollo**
```
Tipo: Standard_D4s_v3 o superior
OS: Windows 11 o Ubuntu 22.04
Disk: 128 GB Premium SSD
IP Pública: NINGUNA ❌
```

**Configuración de seguridad VM:**
- ✅ **Managed Identity**: System-assigned (ON)
- ✅ **No public IP**
- ✅ NSG: Solo permitir entrada desde AzureBastionSubnet o VPN pool
- ✅ Instalar: Python, VS Code, Azure CLI

**Roles para VM Managed Identity:**
- `Cognitive Services OpenAI User`
- `Storage Blob Data Reader`
- `Azure AI User` (en el proyecto Foundry)

### 6️⃣ **Crear Azure Bastion**
```
SKU: Standard (soporta SSH nativo, file transfer, IP-based)
VNet: vnet-foundry-hub (si Hub-Spoke) o vnet-foundry-dev (solo Bastion)
Subnet: AzureBastionSubnet
IP Pública: Crear nueva (solo para Bastion)
```

**Características habilitadas:**
- ✅ Copy/Paste
- ✅ File Upload/Download
- ✅ **Native SSH support** (sin navegador)
- ✅ **IP-based connection** (conectar VMs por IP)
- ✅ Shareable Link (opcional)
- ✅ Kerberos authentication (Windows)

**Métodos de conexión a VM Linux:**

#### Opción 1: SSH desde Azure Portal (Web-based)
```bash
1. Azure Portal → VM → Connect → Bastion
2. Authentication Type: "SSH Private Key" o "Password"
3. Username: azureuser
4. Upload SSH key privada
5. Click "Connect"
```

#### Opción 2: SSH Tunneling para herramientas locales
```bash
# Crear túnel SSH para usar VS Code Remote, PyCharm, etc.
az network bastion tunnel \
  --name bastion-foundry \
  --resource-group rg-foundry-secure-dev \
  --target-resource-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm-name} \
  --resource-port 22 \
  --port 2222

# En otra terminal, conectar via SSH local
ssh azureuser@127.0.0.1 -p 2222 -i ~/.ssh/id_rsa

# Configurar VS Code Remote-SSH:
# ~/.ssh/config:
Host bastionvm
  HostName 127.0.0.1
  Port 2222
  User azureuser
  IdentityFile ~/.ssh/id_rsa
```



### 7️⃣ **Configurar Foundry Managed Network**

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
✅ Agregar tu vnet-foundry-dev (o spoke VNet)
✅ Agregar subnet snet-privatelink
```

### 8️⃣ **Crear Private Endpoint para Foundry**
```
Resource: Tu Azure AI Foundry Hub
Target sub-resource: aistudio
VNet: vnet-foundry-dev (Spoke si usas Hub-Spoke)
Subnet: snet-privatelink
Private DNS: Sí (automático)
```

---

## 🔧 Configuración NSG Crítica

### NSG para `GatewaySubnet` (Solo si usas VPN):
```yaml
⚠️ NO se recomienda aplicar NSG a GatewaySubnet
Azure VPN Gateway maneja su propia seguridad
Si es absolutamente necesario:
  - Permitir: UDP 500, 4500 (IKEv2)
  - Permitir: TCP 443 (SSL VPN)
```

### NSG para `snet-vm-dev`:
```yaml
Inbound:
- Priority 100: Allow from AzureBastionSubnet → VM (3389/RDP o 22/SSH)
- Priority 110: Allow from 172.16.0.0/24 → VM (22/SSH) [Si usas P2S VPN]
- Priority 120: Allow from 192.168.0.0/16 → VM (22, 443) [Si usas S2S VPN]
- Priority 130: Allow from VirtualNetwork → VM (Any) [Tráfico interno]
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to VirtualNetwork → 443 (HTTPS interno)
- Priority 110: Allow to AzureCloud → 443 (Azure APIs)
- Priority 120: Allow to 10.0.0.0/8 → Any (Comunicación VNets privadas)
- Priority 4096: Deny Internet ❌
```

### NSG para `AzureBastionSubnet`:
```yaml
Inbound:
- Priority 100: Allow from GatewayManager → 443
- Priority 110: Allow from Internet → 443
- Priority 120: Allow from AzureLoadBalancer → 443
- Priority 130: Allow from VirtualNetwork → 8080, 5701
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to VirtualNetwork → 22, 3389
- Priority 110: Allow to AzureCloud → 443
- Priority 120: Allow to Internet → 80 (cert validation)
- Priority 130: Allow to VirtualNetwork → 8080, 5701
```

### NSG para `snet-privatelink`:
```yaml
Inbound:
- Priority 100: Allow from VirtualNetwork → 443
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to AzureCloud → 443
- Priority 4096: Deny All
```

---

## ⚡ Quick Start (Orden de Ejecución)

### Escenario A: Solo Bastion (Simple)
```bash
1. Crear Resource Group
   └─ rg-foundry-secure-dev

2. Crear VNet optimizada (10.1.0.0/24)
   └─ AzureBastionSubnet (10.1.0.0/26)
   └─ snet-vm-dev (10.1.0.64/27)
   └─ snet-privatelink (10.1.0.96/28)

3. Crear NSGs y aplicar a subnets

4. Crear VM (sin IP pública)
   └─ Enable Managed Identity
   └─ Generate SSH key pair

5. Crear Azure Bastion (SKU Standard)
   └─ Enable native SSH support

6. En Foundry Hub:
   └─ Enable Managed Network
   └─ Create Private Endpoints

7. Crear Private Endpoint de Foundry en VNet

8. Asignar roles RBAC a VM Managed Identity

9. Conectar vía Bastion SSH (portal o CLI)
```

### Escenario B: VPN Gateway + Bastion (Corporativo)
```bash
1. Crear Resource Group
   └─ rg-foundry-secure-dev

2. Crear VNet Hub optimizada (10.0.0.0/24)
   └─ GatewaySubnet (10.0.0.0/27)
   └─ AzureBastionSubnet (10.0.0.32/26)

3. Crear VNet Spoke optimizada (10.1.0.0/24)
   └─ snet-vm-dev (10.1.0.0/27)
   └─ snet-privatelink (10.1.0.32/28)

4. Configurar VNet Peering (Hub ↔ Spoke)
   └─ Allow gateway transit en Hub
   └─ Use remote gateways en Spoke

5. Crear VPN Gateway en Hub
   └─ SKU: VpnGw2, Gen2, Route-based

6. Configurar VPN Connection
   Option A: Point-to-Site
     └─ Address pool: 172.16.0.0/24
     └─ Tunnel: OpenVPN or IKEv2
   Option B: Site-to-Site
     └─ Local Network Gateway + IPsec

7. Crear NSGs optimizados

8. Crear VM en Spoke VNet (sin IP pública)

9. Crear Azure Bastion en Hub

10. Configurar Foundry Managed Network

11. Crear Private Endpoint en Spoke

12. Asignar roles RBAC

13. Conectar desde VPN Client o Bastion
```

---

## 🔌 Configuración de Clientes VPN

### Point-to-Site: Cliente OpenVPN (Windows/Mac/Linux)

#### 1. Descargar configuración VPN desde Azure Portal
```bash
Azure Portal → VPN Gateway → Point-to-site configuration → Download VPN client
```

#### 2. Instalar cliente OpenVPN
```bash
# Windows
Download: https://openvpn.net/community-downloads/

# Mac
brew install openvpn-connect

# Linux (Ubuntu)
sudo apt-get install openvpn
```

#### 3. Conectar usando el perfil descargado
```bash
# Linux/Mac
sudo openvpn --config AzureVPN/azurevpnconfig.ovpn

# Windows: Importar .ovpn en OpenVPN GUI
```

### Point-to-Site: Azure VPN Client (Recomendado para Azure AD)

#### 1. Descargar Azure VPN Client
```
Windows: https://aka.ms/azvpnclientdownload
Mac: App Store → "Azure VPN Client"
```

#### 2. Importar perfil de VPN
```bash
1. Abrir Azure VPN Client
2. Click "+" → Import
3. Seleccionar azurevpnconfig.xml descargado
4. Autenticarse con Azure AD
5. Click "Connect"
```

#### 3. Verificar conexión
```bash
# Verificar IP del pool VPN
ip addr show  # Linux/Mac
ipconfig      # Windows

# Ver IP 172.16.0.x asignada

# Probar conectividad a VM privada
ping 10.1.0.4  # IP privada de VM
ssh azureuser@10.1.0.4  # SSH directo
```

---

## 🔐 Configuración de SSH Keys y Tunneling

### Generar SSH Keys para Bastion
```bash
# En máquina local
ssh-keygen -t rsa -b 4096 -C "azure-bastion-key" -f ~/.ssh/id_rsa_bastion

# Agregar key pública a VM durante creación:
# Portal → VM → Create → SSH public key
# Pegar contenido de ~/.ssh/id_rsa_bastion.pub
```

### SSH Tunneling para VS Code Remote Development

#### 1. Script de túnel permanente
```bash
#!/bin/bash
# bastion-tunnel.sh

VM_ID="/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm}"
BASTION_NAME="bastion-foundry"
RG="rg-foundry-secure-dev"
LOCAL_PORT=2222

echo "🔌 Creando túnel SSH..."
az network bastion tunnel \
  --name $BASTION_NAME \
  --resource-group $RG \
  --target-resource-id $VM_ID \
  --resource-port 22 \
  --port $LOCAL_PORT
```

#### 2. Configurar VS Code Remote SSH
```bash
# Editar ~/.ssh/config
nano ~/.ssh/config

# Agregar:
Host bastion-foundry-vm
    HostName 127.0.0.1
    Port 2222
    User azureuser
    IdentityFile ~/.ssh/id_rsa_bastion
    StrictHostKeyChecking no
```

#### 3. Conectar desde VS Code
```bash
1. VS Code → Install "Remote - SSH"
2. Ctrl+Shift+P → "Remote-SSH: Connect"
3. Select "bastion-foundry-vm"
4. Desarrollar directamente en VM
```

### SSH Tunneling para APP DESAROLLADA Y PRUEBAS
```bash
# Iniciar túnel en background
./bastion-tunnel.sh &

# SSH y lanzar APP
ssh -p 2222 azureuser@127.0.0.1 'appdevelop --no-browser --port=8888'

# Forward puerto APP
ssh -p 2222 -L 8888:localhost:8888 azureuser@127.0.0.1

# Abrir: http://localhost:8888
```

### Port Forwarding múltiple
```bash
ssh -p 2222 azureuser@127.0.0.1 \
  -L 8888:localhost:8888 \  # Jupyter
  -L 5000:localhost:5000 \  # Flask
  -L 3000:localhost:3000    # Node.js
```

---

## 🔒 Validaciones de Seguridad

**Checklist final:**
- [ ] VM no tiene IP pública
- [ ] No hay Internet outbound (excepto Azure services)
- [ ] Bastion es único punto HTTP/HTTPS
- [ ] VPN Gateway configurado (si aplica)
- [ ] VNet Peering habilitado (si Hub-Spoke)
- [ ] Private Endpoints para Foundry
- [ ] NSGs aplicados a todas subnets
- [ ] Managed Identity en VM
- [ ] Roles RBAC asignados
- [ ] DNS privado resuelve correctamente
- [ ] SSH keys configuradas (no passwords)
- [ ] Túnel SSH funciona
- [ ] Conexión VPN establecida (si aplica)
- [ ] GatewaySubnet sin NSG
- [ ] VNets con CIDR optimizados (/27, /28)

**Pruebas de conectividad:**
```bash
# Desde VM, verificar conectividad privada

# 1. Resolver DNS privado
nslookup your-foundry.services.ai.azure.com
# Debe resolver a 10.x.x.x (IP privada)

# 2. Probar HTTPS
curl -I https://your-foundry.services.ai.azure.com
# Debe funcionar via Private Endpoint

# 3. Verificar NO hay Internet público
curl -I https://www.google.com
# Debe fallar

# 4. Verificar Azure services
curl -I https://management.azure.com
# Debe funcionar via AzureCloud service tag
```

---

## 📚 Documentación Oficial

### Azure AI Foundry
- **Managed Network**: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-managed-network
- **Private Link**: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link
- **RBAC**: https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/rbac-azure-ai-foundry

### Azure Bastion
- **Overview**: https://learn.microsoft.com/en-us/azure/bastion/bastion-overview
- **Native SSH**: https://learn.microsoft.com/en-us/azure/bastion/connect-vm-native-client
- **SSH Tunneling**: https://learn.microsoft.com/en-us/azure/bastion/connect-vm-ssh-linux
- **File Transfer**: https://learn.microsoft.com/en-us/azure/bastion/vm-upload-download-native

### VPN Gateway
- **Overview**: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways
- **Point-to-Site**: https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-about
- **Site-to-Site**: https://learn.microsoft.com/en-us/azure/vpn-gateway/tutorial-site-to-site-portal
- **SKUs**: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsku

### Networking
- **VNet Peering**: https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview
- **Hub-Spoke**: https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
- **NSG Rules**: https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview
- **Private Endpoints**: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview

---

## 🎯 Resumen Ejecutivo

### Opción 1: Azure Bastion Solo (Individual/Equipos Pequeños)

**Configuración:**
- VNet optimizada: 10.1.0.0/24
- Subnets: /26, /27, /28 (segmentación mínima)
- Azure Bastion Standard con SSH nativo
- Private Endpoints a Foundry

**Métodos de acceso:**
- 🌐 Portal web
- 💻 Azure CLI SSH nativo
- 🔌 SSH tunnel → VS Code Remote
- 🖥️ RDP para Windows

**Ideal para:**
- 1-10 usuarios
- Trabajo remoto individual
- Menor complejidad
- Setup rápido

---

### Opción 2: VPN Gateway + Bastion (Corporativo)

**Configuración:**
- Topología Hub-Spoke
- VNet Hub: 10.0.0.0/24 con GatewaySubnet /27
- VNet Spoke: 10.1.0.0/24 con subnets optimizadas
- VPN Gateway (P2S o S2S)
- Bastion como backup

**Métodos de acceso:**
- 🔐 VPN Client → Acceso directo
- 🌐 Azure Bastion (backup)
- 💻 SSH/RDP nativo via VPN
- 🔧 Tools locales (kubectl, etc.)

**Ideal para:**
- Equipos 10 usuarios
- Oficina corporativa completa
- Alta disponibilidad
- Mejor performance

---

## 📊 Comparación: Bastion vs VPN

| Característica | Azure Bastion | VPN Gateway |
|----------------|---------------|-------------|
| **Acceso** | Portal/CLI | Cliente VPN |
| **Setup** | Simple | Complejo |
| **Usuarios** | Ilimitados | 128 P2S / ∞ S2S |
| **Performance** | Buena | Excelente |
| **Firewall** | Siempre OK (443) | Puede bloquearse |
| **VS Code** | Via tunnel | Directo |
| **Mantenimiento** | Mínimo | Moderado |

---

## 📝 Segmentación de Red - Mejores Prácticas

### Principios de diseño:
1. ✅ **Minimizar espacio IP** - Usar CIDR más pequeño posible
2. ✅ **Reservar para crecimiento** - Dejar 25% espacio libre
3. ✅ **Segregar por función** - Subnet por tipo de recurso
4. ✅ **Evitar solapamiento** - No conflictos con on-prem

### Tabla de dimensionamiento rápido:

| Necesidad | CIDR | IPs Totales | IPs Usables | Ejemplo |
|-----------|------|-------------|-------------|---------|
| 1-6 recursos | /28 | 16 | 11 | Private Endpoints |
| 7-22 recursos | /27 | 32 | 27 | VMs pequeño equipo |

**Nota:** Azure reserva 5 IPs por subnet:
- Primera IP (network address)
- Segunda IP (default gateway)
- Tercera y cuarta IP (Azure DNS)
- Última IP (broadcast address)

---

## 🔐 Cuándo usar cada solución

### Solo Azure Bastion:
- ✅ 1-10 usuarios remotos
- ✅ Sin infraestructura VPN existente
- ✅ Acceso administrativo ocasional

### VPN + Bastion:
- ✅ 10+ usuarios
- ✅ Oficina corporativa completa
- ✅ Desarrollo intensivo diario
- ✅ Múltiples aplicaciones/servicios
- ✅ Requiere alta disponibilidad

### Ambos (Recomendado Enterprise):
- ✅ Alta disponibilidad
- ✅ Usuarios mixtos (VPN + web)
- ✅ Compliance estricto
- ✅ Bastion como failover

---

---

**Fecha:** Noviembre 2025  
