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

### 1️⃣ **Crear VNet Segura (Segmentos Mínimos Recomendados)**
```
VNet: "vnet-foundry-dev" (10.250.0.0/24) - 256 IPs
├── Subnet 1: "AzureBastionSubnet" (10.250.0.0/27) - 32 IPs
│   └── Para Azure Bastion (nombre OBLIGATORIO, mínimo /26)
├── Subnet 2: "snet-vm-dev" (10.250.0.64/27) - 32 IPs
│   └── Para VM de desarrollo (hasta ~25 VMs)
└── Subnet 3: "snet-privatelink" (10.250.0.128/27) - 32 IPs
    └── Para Private Endpoints de Foundry
```

**⚠️ Recomendaciones de segmentación:**
- ✅ Usar rangos /27 (32 IPs) o /28 (16 IPs) para minimizar superficie de ataque
- ✅ Azure reserva 5 IPs por subnet, considerar esto en el sizing
- ✅ AzureBastionSubnet requiere mínimo /26, pero /27 es suficiente para la mayoría
- ✅ VNet completa puede ser /24 (256 IPs) en lugar de /16 (65,536 IPs)
- ✅ Evitar desperdicio de direcciones IP con subnets sobredimensionadas

---

### Escenario B: VPN Gateway + Hub-Spoke (Acceso Corporativo)

### 1️⃣ **Crear VNet Hub (Conectividad Central - Segmentos Mínimos)**
```
VNet Hub: "vnet-foundry-hub" (10.250.0.0/24) - 256 IPs
├── Subnet 1: "GatewaySubnet" (10.250.0.0/27) - 32 IPs - OBLIGATORIO este nombre
│   └── Para VPN Gateway (mínimo /27)
├── Subnet 2: "AzureBastionSubnet" (10.250.0.32/27) - 32 IPs - OBLIGATORIO este nombre
│   └── Para Azure Bastion
└── Subnet 3: "snet-firewall" (10.250.0.64/26) - 64 IPs - Opcional
    └── Para Azure Firewall (requiere mínimo /26)
```

### 2️⃣ **Crear VNet Spoke (Recursos de Desarrollo - Segmentos Mínimos)**
```
VNet Spoke: "vnet-foundry-dev" (10.251.0.0/24) - 256 IPs
├── Subnet 1: "snet-vm-dev" (10.251.0.0/27) - 32 IPs
│   └── Para VMs de desarrollo (hasta ~25 VMs)
├── Subnet 2: "snet-privatelink" (10.251.0.32/27) - 32 IPs
│   └── Para Private Endpoints de Foundry (hasta ~25 endpoints)
└── Subnet 3: "snet-aks" (10.251.0.64/26) - 64 IPs - Opcional
    └── Para clusters Kubernetes pequeños si es necesario
```

**⚠️ Recomendaciones de segmentación Hub-Spoke:**
- ✅ Hub VNet: /24 (256 IPs) es suficiente para infraestructura
- ✅ Spoke VNet: /24 (256 IPs) por proyecto o equipo
- ✅ GatewaySubnet: /27 (32 IPs) soporta hasta ~20 túneles VPN
- ✅ Usar múltiples Spoke VNets pequeños en lugar de uno grande
- ✅ Facilita aislamiento por proyecto/ambiente (dev/test/prod)
- ✅ Private Endpoints: 1 IP por endpoint, planear según servicios

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
Address Pool: 172.16.0.0/24
Tunnel Type: OpenVPN (SSL) o IKEv2
Authentication: Azure Certificate o Azure AD

Características:
- ✅ Usuarios individuales se conectan desde cualquier lugar
- ✅ Cliente VPN en laptops/workstations
- ✅ Ideal para trabajo remoto
- ⚠️ Requiere configuración de certificados o Azure AD
```

#### Opción B: Site-to-Site (S2S) - Para oficina corporativa
```yaml
Local Network Gateway:
- On-premises IP: IP pública de tu firewall corporativo
- Address Space: Rango IP de red local (ej: 192.168.0.0/16)

Connection:
- Type: IPsec
- Shared Key: <clave-precompartida-segura>

Características:
- ✅ Toda la oficina tiene acceso automático
- ✅ No requiere VPN client individual
- ✅ Ideal para equipos grandes
- ⚠️ Requiere dispositivo VPN compatible en oficina
```

---

### 5️⃣ **Crear VM de Desarrollo**
```
Tipo: Standard_D4s_v3 o superior (4 vCPUs, 16 GB RAM)
OS: Ubuntu 22.04 LTS (recomendado) o Windows 11
Disk: 128 GB Premium SSD (mínimo)
IP Pública: NINGUNA ❌
```

**Configuración de seguridad VM:**
- ✅ **Managed Identity**: System-assigned (ON)
- ✅ **No public IP**
- ✅ NSG: Solo permitir entrada desde AzureBastionSubnet
- ✅ SSH key authentication (no passwords)

**Roles para VM Managed Identity:**
- `Cognitive Services OpenAI User`
- `Storage Blob Data Reader`
- `Azure AI User` (en el proyecto Foundry)

---

### 5.1 **Instalación de Herramientas de Desarrollo en VM**

#### Conectar a la VM vía Bastion
```bash
# Opción 1: Portal Azure
Azure Portal → VM → Connect → Bastion

# Opción 2: Azure CLI
az network bastion ssh \
  --name bastion-foundry \
  --resource-group rg-foundry-secure-dev \
  --target-resource-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm-name} \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

#### Script de Instalación Completa (Ubuntu 22.04)

```bash
#!/bin/bash
# install-dev-tools.sh - Instalación completa de ambiente de desarrollo

set -e

echo "🚀 Iniciando instalación de herramientas de desarrollo..."

# ============================================================================
# 1. ACTUALIZAR SISTEMA
# ============================================================================
echo "📦 Actualizando sistema..."
sudo apt-get update && sudo apt-get upgrade -y

# ============================================================================
# 2. PYTHON 3.11+ Y HERRAMIENTAS
# ============================================================================
echo "🐍 Instalando Python 3.11 y herramientas..."
sudo apt-get install -y software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get update
sudo apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    python3.11-distutils

# Establecer Python 3.11 como predeterminado
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Actualizar pip
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11
python3 -m pip install --upgrade pip setuptools wheel

# ============================================================================
# 3. DOCKER Y DOCKER COMPOSE
# ============================================================================
echo "🐳 Instalando Docker..."
# Eliminar versiones antiguas
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

# Instalar dependencias
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Agregar Docker GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Agregar repositorio Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Habilitar Docker en boot
sudo systemctl enable docker
sudo systemctl start docker

echo "✅ Docker instalado: $(docker --version)"

# ============================================================================
# 4. AZURE CLI
# ============================================================================
echo "☁️ Instalando Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
echo "✅ Azure CLI instalado: $(az --version | head -n1)"

# ============================================================================
# 5. GIT Y HERRAMIENTAS DE CONTROL DE VERSIONES
# ============================================================================
echo "📚 Instalando Git..."
sudo apt-get install -y git git-lfs
git lfs install
echo "✅ Git instalado: $(git --version)"

# ============================================================================
# 6. HERRAMIENTAS DE BUILD Y DESARROLLO
# ============================================================================
echo "🔧 Instalando herramientas de build..."
sudo apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    pkg-config \
    cmake \
    wget \
    curl \
    vim \
    nano \
    htop \
    tree \
    jq \
    unzip \
    zip

# ============================================================================
# 7. PYTHON PACKAGES PARA AI/ML
# ============================================================================
echo "📚 Instalando paquetes Python para AI/ML..."
python3 -m pip install --upgrade \
    azure-identity \
    azure-ai-projects \
    azure-ai-agents \
    azure-ai-inference \
    azure-core \
    langchain \
    langchain-openai \
    langchain-core \
    langchain-community \
    openai \
    python-dotenv \
    requests \
    aiohttp \
    pandas \
    numpy \
    pydantic \
    pydantic-settings \
    fastapi \
    uvicorn \
    black \
    flake8 \
    pytest \
    pytest-asyncio \
    python-multipart

# ============================================================================
# 8. NODE.JS Y NPM (Opcional, para tooling)
# ============================================================================
echo "📦 Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
echo "✅ Node.js instalado: $(node --version)"
echo "✅ npm instalado: $(npm --version)"

# ============================================================================
# 9. CONFIGURAR DIRECTORIO DE TRABAJO
# ============================================================================
echo "📁 Configurando directorios de trabajo..."
mkdir -p ~/projects/foundry-app
mkdir -p ~/projects/docker-apps
mkdir -p ~/.azure

# ============================================================================
# 10. CREAR ARCHIVO DE VARIABLES DE ENTORNO
# ============================================================================
echo "🔐 Creando template de variables de entorno..."
cat > ~/projects/foundry-app/.env.template << 'EOF'
# Azure AI Foundry Configuration
AZURE_AI_PROJECT_CONNECTION_STRING="your-connection-string-here"
AZURE_OPENAI_ENDPOINT="https://your-endpoint.openai.azure.com/"
AZURE_OPENAI_API_VERSION="2024-02-15-preview"
AZURE_OPENAI_DEPLOYMENT_NAME="gpt-4o"

# Azure Authentication (Managed Identity - no credentials needed)
# La VM usa Managed Identity automáticamente

# Application Settings
LOG_LEVEL="INFO"
APP_PORT=8000
EOF

echo "✅ Template .env creado en ~/projects/foundry-app/.env.template"

# ============================================================================
# 11. VALIDAR INSTALACIONES
# ============================================================================
echo ""
echo "✅ ============================================"
echo "✅ INSTALACIÓN COMPLETA"
echo "✅ ============================================"
echo ""
echo "Versiones instaladas:"
echo "- Python: $(python3 --version)"
echo "- pip: $(pip3 --version)"
echo "- Docker: $(docker --version)"
echo "- Docker Compose: $(docker compose version)"
echo "- Azure CLI: $(az --version | head -n1)"
echo "- Git: $(git --version)"
echo "- Node.js: $(node --version)"
echo ""
echo "⚠️  IMPORTANTE: Cierra sesión y vuelve a conectar para aplicar cambios de Docker group"
echo "⚠️  Ejecuta: exit"
echo ""
echo "Próximos pasos:"
echo "1. Copia ~/projects/foundry-app/.env.template a .env"
echo "2. Configura tus variables de entorno en .env"
echo "3. Autentica con Azure: az login --use-device-code (si es necesario)"
echo "4. Verifica Managed Identity: az account show"
echo ""
```

#### Ejecutar instalación
```bash
# Copiar script a la VM
scp install-dev-tools.sh azureuser@vm-ip:~/

# O vía Bastion tunnel:
# 1. Crear túnel: az network bastion tunnel ...
# 2. Usar SCP local: scp -P 2222 install-dev-tools.sh azureuser@127.0.0.1:~/

# Conectar a VM y ejecutar
chmod +x install-dev-tools.sh
./install-dev-tools.sh

# Cerrar sesión y reconectar para aplicar cambios de Docker
exit
```

---

### 5.2 **Estructura de Proyecto Recomendada para Aplicación LangChain**

```bash
~/projects/foundry-app/
├── .env                          # Variables de entorno (no commitear)
├── .env.template                 # Template de variables
├── .gitignore
├── requirements.txt              # Dependencias Python
├── Dockerfile                    # Contenedor de la aplicación
├── docker-compose.yml            # Orquestación local
├── README.md
├── pyproject.toml               # Configuración del proyecto (opcional)
│
├── src/                         # Código fuente
│   ├── __init__.py
│   ├── main.py                  # Entry point de la aplicación
│   ├── config.py                # Configuración
│   │
│   ├── agents/                  # Agentes de AI Foundry
│   │   ├── __init__.py
│   │   └── foundry_agent.py
│   │
│   ├── chains/                  # Chains de LangChain
│   │   ├── __init__.py
│   │   ├── rag_chain.py
│   │   └── conversation_chain.py
│   │
│   ├── tools/                   # Tools personalizadas
│   │   ├── __init__.py
│   │   └── custom_tools.py
│   │
│   └── api/                     # API REST (FastAPI)
│       ├── __init__.py
│       ├── routes.py
│       └── models.py
│
├── tests/                       # Tests unitarios
│   ├── __init__.py
│   └── test_agents.py
│
└── scripts/                     # Scripts de utilidad
    ├── setup.sh
    └── test_connection.py
```

---

### 5.3 **Archivo requirements.txt Completo**

```txt
# requirements.txt
# Azure SDK
azure-identity==1.15.0
azure-ai-projects==1.0.0b11
azure-ai-agents==1.0.0b5
azure-ai-inference==1.0.0b4
azure-core==1.29.5

# LangChain Stack
langchain==0.1.0
langchain-openai==0.0.5
langchain-core==0.1.10
langchain-community==0.0.13

# OpenAI
openai==1.12.0

# Web Framework
fastapi==0.109.0
uvicorn[standard]==0.27.0
python-multipart==0.0.6

# Data Processing
pandas==2.1.4
numpy==1.26.3
pydantic==2.5.3
pydantic-settings==2.1.0

# Utilities
python-dotenv==1.0.0
requests==2.31.0
aiohttp==3.9.1
httpx==0.26.0

# Development
black==24.1.1
flake8==7.0.0
pytest==7.4.4
pytest-asyncio==0.23.3

# Monitoring & Logging
azure-monitor-opentelemetry==1.2.0
opentelemetry-api==1.22.0
opentelemetry-sdk==1.22.0
```

---

### 5.4 **Dockerfile para la Aplicación**

```dockerfile
# Dockerfile
FROM python:3.11-slim

# Metadata
LABEL maintainer="tu-equipo@empresa.com"
LABEL description="LangChain App con Azure AI Foundry"

# Variables de entorno
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalar dependencias del sistema
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar requirements e instalar dependencias
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código de la aplicación
COPY src/ ./src/

# Exponer puerto
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Comando de inicio
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### 5.5 **docker-compose.yml**

```yaml
# docker-compose.yml
version: '3.9'

services:
  foundry-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: foundry-langchain-app
    ports:
      - "8000:8000"
    environment:
      # Azure Configuration (Managed Identity se maneja automáticamente)
      - AZURE_AI_PROJECT_CONNECTION_STRING=${AZURE_AI_PROJECT_CONNECTION_STRING}
      - AZURE_OPENAI_ENDPOINT=${AZURE_OPENAI_ENDPOINT}
      - AZURE_OPENAI_DEPLOYMENT_NAME=${AZURE_OPENAI_DEPLOYMENT_NAME}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
    volumes:
      - ./src:/app/src:ro
      - ./logs:/app/logs
    restart: unless-stopped
    networks:
      - foundry-network
    # Managed Identity: El contenedor hereda la identidad de la VM
    # No se requieren credenciales explícitas

networks:
  foundry-network:
    driver: bridge

volumes:
  logs:
```

---

### 5.6 **Ejemplo de Aplicación LangChain (src/main.py)**

```python
# src/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from langchain_openai import AzureChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage
import os
from dotenv import load_dotenv

# Cargar variables de entorno
load_dotenv()

# Inicializar FastAPI
app = FastAPI(
    title="Azure AI Foundry LangChain App",
    description="Aplicación con LangChain y Azure AI Foundry",
    version="1.0.0"
)

# Configuración
PROJECT_CONNECTION_STRING = os.getenv("AZURE_AI_PROJECT_CONNECTION_STRING")
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
DEPLOYMENT_NAME = os.getenv("AZURE_OPENAI_DEPLOYMENT_NAME", "gpt-4o")

# Inicializar clientes con Managed Identity
credential = DefaultAzureCredential()

# Cliente de AI Foundry
project_client = AIProjectClient.from_connection_string(
    credential=credential,
    conn_str=PROJECT_CONNECTION_STRING
)

# LangChain con Azure OpenAI
llm = AzureChatOpenAI(
    azure_endpoint=AZURE_OPENAI_ENDPOINT,
    azure_deployment=DEPLOYMENT_NAME,
    api_version="2024-02-15-preview",
    azure_ad_token_provider=credential.get_token("https://cognitiveservices.azure.com/.default")
)

# Modelos Pydantic
class ChatRequest(BaseModel):
    message: str
    system_prompt: str = "Eres un asistente útil."

class ChatResponse(BaseModel):
    response: str
    model: str

# Endpoints
@app.get("/")
async def root():
    return {"message": "Azure AI Foundry LangChain App está corriendo"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        messages = [
            SystemMessage(content=request.system_prompt),
            HumanMessage(content=request.message)
        ]
        
        response = await llm.ainvoke(messages)
        
        return ChatResponse(
            response=response.content,
            model=DEPLOYMENT_NAME
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/foundry/agents")
async def list_agents():
    """Listar agentes disponibles en AI Foundry"""
    try:
        # Ejemplo de uso del cliente de Foundry
        agents = project_client.agents.list_agents()
        return {"agents": [{"id": a.id, "name": a.name} for a in agents]}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

### 5.7 **Script de Test de Conexión**

```python
# scripts/test_connection.py
"""
Script para validar conectividad con Azure AI Foundry
"""
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
import os
from dotenv import load_dotenv

load_dotenv()

def test_connection():
    print("🔍 Probando conexión a Azure AI Foundry...")
    
    try:
        # Managed Identity
        credential = DefaultAzureCredential()
        print("✅ Managed Identity inicializada")
        
        # Cliente de proyecto
        connection_string = os.getenv("AZURE_AI_PROJECT_CONNECTION_STRING")
        project = AIProjectClient.from_connection_string(
            credential=credential,
            conn_str=connection_string
        )
        print("✅ Cliente de proyecto inicializado")
        
        # Listar agentes
        agents = project.agents.list_agents()
        print(f"✅ Agentes encontrados: {len(list(agents))}")
        
        print("\n🎉 ¡Conexión exitosa a Azure AI Foundry!")
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    test_connection()
```

---

### 5.8 **Comandos de Uso Común**

```bash
# Iniciar ambiente virtual (opcional)
python3 -m venv venv
source venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt

# Ejecutar aplicación directamente
python src/main.py

# O con uvicorn
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# Build Docker image
docker build -t foundry-langchain-app:latest .

# Ejecutar con Docker Compose
docker compose up -d

# Ver logs
docker compose logs -f

# Detener
docker compose down

# Test de conexión
python scripts/test_connection.py
```

---

### 6️⃣ **Crear Azure Bastion**
```
SKU: Standard (soporta copy/paste, file transfer, SSH, IP-based)
VNet: vnet-foundry-hub (si usas Hub-Spoke) o vnet-foundry-dev (solo Bastion)
Subnet: AzureBastionSubnet
IP Pública: Crear nueva (solo para Bastion)
```

**Características habilitadas:**
- ✅ Copy/Paste
- ✅ File Upload/Download
- ✅ **Native SSH support** (nuevo)
- ✅ **IP-based connection** (para conectar a VMs por IP)
- ✅ Shareable Link (opcional, para otros usuarios)
- ✅ Kerberos authentication (opcional, para Windows)

**Métodos de conexión a VM Linux:**

#### Opción 1: SSH desde Azure Portal (Web-based)
```bash
1. Azure Portal → VM → Connect → Bastion
2. Authentication Type: "SSH Private Key from Local File" o "Password"
3. Username: azureuser
4. Upload tu SSH key privada
5. Click "Connect"
```

#### Opción 2: SSH desde Azure CLI (Nativo)
```bash
# Instalar extensión de Bastion
az extension add --name bastion

# Conectar por SSH nativo
az network bastion ssh \
  --name bastion-foundry \
  --resource-group rg-foundry-secure-dev \
  --target-resource-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm-name} \
  --auth-type password \
  --username azureuser

# O usando SSH key
az network bastion ssh \
  --name bastion-foundry \
  --resource-group rg-foundry-secure-dev \
  --target-resource-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm-name} \
  --auth-type ssh-key \
  --username azureuser \
  --ssh-key ~/.ssh/id_rsa
```

#### Opción 3: SSH Tunneling para herramientas locales
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
# Host bastionvm
#   HostName 127.0.0.1
#   Port 2222
#   User azureuser
#   IdentityFile ~/.ssh/id_rsa
```

#### Opción 4: RDP para Windows VM
```bash
# Desde Azure CLI
az network bastion rdp \
  --name bastion-foundry \
  --resource-group rg-foundry-secure-dev \
  --target-resource-id /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm-name}
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
✅ Agregar tu vnet-foundry-dev
✅ Agregar subnet snet-privatelink
```

### 8️⃣ **Crear Private Endpoint para Foundry**
```
Resource: Tu Azure AI Foundry Hub
Target sub-resource: aistudio
VNet: vnet-foundry-dev
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
- Priority 110: Allow from VPN Address Pool → VM (22/SSH) [Si usas VPN]
- Priority 120: Allow from 10.0.0.0/8 → VM (22, 443) [Tráfico interno VNet]
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to VirtualNetwork → 443 (HTTPS)
- Priority 110: Allow to AzureCloud → 443 (Azure APIs)
- Priority 120: Allow to 10.0.0.0/8 → Any (Comunicación entre VNets)
- Priority 4096: Deny Internet ❌
```

### NSG para `AzureBastionSubnet`:
```yaml
Inbound:
- Priority 100: Allow GatewayManager → 443 (Azure management)
- Priority 110: Allow Internet → 443 (Portal de usuario)
- Priority 120: Allow AzureLoadBalancer → 443 (Health probes)
- Priority 130: Allow from VirtualNetwork → 8080, 5701 (Bastion internal)
- Priority 4096: Deny All

Outbound:
- Priority 100: Allow to VirtualNetwork → 22, 3389 (SSH/RDP a VMs)
- Priority 110: Allow to AzureCloud → 443 (Azure services)
- Priority 120: Allow to Internet → 80 (Session cert validation)
- Priority 130: Allow to VirtualNetwork → 8080, 5701 (Bastion internal)
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

2. Crear VNet con subnets mínimas
   └─ VNet: 10.250.0.0/24 (256 IPs)
   └─ AzureBastionSubnet: 10.250.0.0/27 (32 IPs)
   └─ snet-vm-dev: 10.250.0.64/27 (32 IPs)
   └─ snet-privatelink: 10.250.0.128/27 (32 IPs)

3. Crear NSGs y aplicar a subnets

4. Crear VM (sin IP pública)
   └─ Enable Managed Identity
   └─ Generate SSH key pair

5. Crear Azure Bastion (SKU Standard)
   └─ Enable native SSH support

6. En Foundry Hub:
   └─ Enable Managed Network
   └─ Create Private Endpoints

7. Crear Private Endpoint de Foundry en tu VNet

8. Asignar roles RBAC a VM Managed Identity

9. Conectar vía Bastion SSH (portal o CLI)

10. Validar conectividad privada a Foundry
```

### Escenario B: VPN Gateway + Bastion (Corporativo)
```bash
1. Crear Resource Group
   └─ rg-foundry-secure-dev

2. Crear VNet Hub con subnets mínimas
   └─ VNet Hub: 10.250.0.0/24 (256 IPs)
   └─ GatewaySubnet: 10.250.0.0/27 (32 IPs)
   └─ AzureBastionSubnet: 10.250.0.32/27 (32 IPs)
   └─ snet-firewall: 10.250.0.64/26 (64 IPs) [opcional]

3. Crear VNet Spoke con subnets mínimas
   └─ VNet Spoke: 10.251.0.0/24 (256 IPs)
   └─ snet-vm-dev: 10.251.0.0/27 (32 IPs)
   └─ snet-privatelink: 10.251.0.32/27 (32 IPs)

4. Configurar VNet Peering (Hub ↔ Spoke)
   └─ Allow gateway transit en Hub
   └─ Use remote gateways en Spoke

5. Crear VPN Gateway en Hub
   └─ SKU: VpnGw2
   └─ Tipo: Route-based
   └─ Generation: Gen2
   └─ ⚠️ Provisionamiento puede tardar 30-45 minutos

6. Configurar VPN Connection
   Option A: Point-to-Site (usuarios remotos)
     └─ Address pool: 172.16.0.0/24
     └─ Tunnel: OpenVPN or IKEv2
     └─ Auth: Azure Certificate or Azure AD
   
   Option B: Site-to-Site (oficina corporativa)
     └─ Local Network Gateway
     └─ Connection con IPsec
     └─ Shared key

7. Crear NSGs y aplicar a todas las subnets

8. Crear VM en Spoke VNet (sin IP pública)
   └─ Enable Managed Identity

9. Crear Azure Bastion en Hub (SKU Standard)
   └─ Enable SSH native support

10. En Foundry Hub:
    └─ Enable Managed Network
    └─ Create Private Endpoints

11. Crear Private Endpoint de Foundry en Spoke VNet

12. Asignar roles RBAC a VM Managed Identity

13. Conectar desde:
    └─ VPN Client → Acceso directo a VM via SSH
    └─ Azure Bastion → Backup si VPN falla
    └─ Azure CLI → az network bastion ssh

14. Validar conectividad privada a Foundry
```

---

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
Download from: https://openvpn.net/community-downloads/

# Mac
brew install openvpn-connect

# Linux (Ubuntu)
sudo apt-get install openvpn
```

#### 3. Conectar usando el perfil descargado
```bash
# Linux/Mac
sudo openvpn --config AzureVPN/azurevpnconfig.ovpn

# Windows: Importar archivo .ovpn en OpenVPN GUI
```

### Point-to-Site: Azure VPN Client (Recomendado para Azure AD)

#### 1. Descargar Azure VPN Client
```
Windows: https://aka.ms/azvpnclientdownload
Mac: https://apps.apple.com/app/azure-vpn-client/id1553936137
```

#### 2. Importar perfil de VPN
```bash
1. Abrir Azure VPN Client
2. Click en "+" → Import
3. Seleccionar archivo azurevpnconfig.xml descargado
4. Autenticarse con Azure AD
5. Click en "Connect"
```

#### 3. Verificar conexión
```bash
# Verificar que tienes IP del pool VPN
ip addr show  # Linux/Mac
ipconfig      # Windows

# Deberías ver una IP en el rango 172.16.0.0/24

# Probar conectividad a VM privada
ping 10.1.1.4  # IP privada de tu VM
ssh azureuser@10.1.1.4  # SSH directo sin Bastion
```

---

## 🔐 Configuración de SSH Keys y Tunneling

### Generar SSH Keys para Bastion
```bash
# En tu máquina local
ssh-keygen -t rsa -b 4096 -C "azure-bastion-key" -f ~/.ssh/id_rsa_bastion

# Agregar key pública a VM durante creación:
# Azure Portal → VM → Create → Administrator account → SSH public key
# Pegar contenido de ~/.ssh/id_rsa_bastion.pub
```

### SSH Tunneling para VS Code Remote Development

#### 1. Crear túnel permanente con script
```bash
#!/bin/bash
# bastion-tunnel.sh

VM_ID="/subscriptions/{sub-id}/resourceGroups/rg-foundry-secure-dev/providers/Microsoft.Compute/virtualMachines/vm-foundry-dev"
BASTION_NAME="bastion-foundry"
RESOURCE_GROUP="rg-foundry-secure-dev"
LOCAL_PORT=2222

echo "🔌 Creando túnel SSH a través de Azure Bastion..."
az network bastion tunnel \
  --name $BASTION_NAME \
  --resource-group $RESOURCE_GROUP \
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
    UserKnownHostsFile /dev/null
```

#### 3. Conectar desde VS Code
```bash
1. Abrir VS Code
2. Install extension: "Remote - SSH"
3. Command Palette (Ctrl+Shift+P)
4. "Remote-SSH: Connect to Host"
5. Select "bastion-foundry-vm"
6. ¡Ya puedes desarrollar directamente en la VM!
```

### SSH Tunneling para Aplicación LangChain

```bash
# Iniciar túnel en background
./bastion-tunnel.sh &

# Opción 1: Forward puerto de la aplicación FastAPI
ssh -p 2222 -L 8000:localhost:8000 azureuser@127.0.0.1

# Abrir navegador en: http://localhost:8000
# Acceso a la API: http://localhost:8000/docs (Swagger UI)

# Opción 2: Si la app corre en Docker
ssh -p 2222 azureuser@127.0.0.1 'cd ~/projects/foundry-app && docker compose up'
```

### Port Forwarding para múltiples servicios
```bash
# Forward múltiples puertos simultáneamente
ssh -p 2222 azureuser@127.0.0.1 \
  -L 8000:localhost:8000 \  # FastAPI app
  -L 5432:localhost:5432 \  # PostgreSQL (si se usa)
  -L 6379:localhost:6379    # Redis (si se usa)
```

### Desarrollo con Docker via SSH
```bash
# Conectar y ejecutar comandos Docker remotamente
ssh -p 2222 azureuser@127.0.0.1

# Una vez conectado:
cd ~/projects/foundry-app

# Build y run con Docker Compose
docker compose up --build -d

# Ver logs
docker compose logs -f foundry-app

# Test de la aplicación
curl http://localhost:8000/health
```

---

## 🔒 Validaciones de Seguridad

**Checklist de infraestructura:**
- [ ] VM no tiene IP pública
- [ ] No hay Internet outbound desde VM (excepto Azure services)
- [ ] Bastion es el ÚNICO punto de entrada HTTP/HTTPS
- [ ] VPN Gateway configurado correctamente (si aplica)
- [ ] VNet Peering habilitado entre Hub y Spoke (si aplica)
- [ ] Private Endpoints configurados para Foundry
- [ ] NSGs aplicados correctamente a todas las subnets
- [ ] Managed Identity habilitada en VM
- [ ] Roles RBAC asignados a Managed Identity
- [ ] DNS privado resuelve correctamente
- [ ] SSH keys configuradas (no passwords)
- [ ] Túnel SSH funciona correctamente
- [ ] Conexión VPN establecida (si aplica)
- [ ] Tráfico entre VNets funciona via peering
- [ ] GatewaySubnet NO tiene NSG (recomendado)

**Checklist de herramientas de desarrollo:**
- [ ] Python 3.11+ instalado
- [ ] pip funcionando correctamente
- [ ] Docker y Docker Compose instalados
- [ ] Usuario agregado al grupo docker
- [ ] Azure CLI instalado y funcional
- [ ] Git instalado
- [ ] Managed Identity autenticando correctamente
- [ ] Paquetes Python instalados (langchain, azure-ai-projects, etc.)
- [ ] requirements.txt actualizado
- [ ] Estructura de proyecto creada
- [ ] Variables de entorno configuradas (.env)
- [ ] Docker image se construye sin errores
- [ ] Docker Compose ejecuta la aplicación
- [ ] FastAPI responde en puerto 8000
- [ ] Endpoints /health y / responden correctamente

**Pruebas de conectividad:**
```bash
# Desde VM, verificar conectividad privada
# 1. Resolver DNS privado de Foundry
nslookup your-foundry-endpoint.services.ai.azure.com

# 2. Verificar que resuelve a IP privada (10.x.x.x)
# 3. Probar conexión HTTPS
curl -I https://your-foundry-endpoint.services.ai.azure.com

# 4. Verificar NO hay acceso a Internet público
curl -I https://www.google.com  # Debería fallar

# 5. Verificar acceso a Azure services via Service Endpoints
curl -I https://management.azure.com  # Debería funcionar

# 6. Verificar Managed Identity
az login --identity
az account show

# 7. Test de Python con Azure
python scripts/test_connection.py

# 8. Test de Docker
docker run hello-world

# 9. Test de aplicación local
cd ~/projects/foundry-app
python src/main.py &
curl http://localhost:8000/health

# 10. Test de aplicación en Docker
docker compose up -d
curl http://localhost:8000/health
docker compose logs foundry-app
```

---

## 📚 Documentación Oficial

### Azure AI Foundry
- **Managed Network**: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-managed-network
- **Private Link Foundry**: https://learn.microsoft.com/en-us/azure/ai-foundry/how-to/configure-private-link
- **RBAC Azure AI Foundry**: https://learn.microsoft.com/en-us/azure/ai-foundry/concepts/rbac-azure-ai-foundry

### Azure Bastion
- **Bastion Overview**: https://learn.microsoft.com/en-us/azure/bastion/bastion-overview
- **Native SSH support**: https://learn.microsoft.com/en-us/azure/bastion/connect-vm-native-client
- **SSH Tunneling**: https://learn.microsoft.com/en-us/azure/bastion/connect-vm-ssh-linux
- **Upload/Download files**: https://learn.microsoft.com/en-us/azure/bastion/vm-upload-download-native

### VPN Gateway
- **VPN Gateway Overview**: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways
- **Point-to-Site VPN**: https://learn.microsoft.com/en-us/azure/vpn-gateway/point-to-site-about
- **Site-to-Site VPN**: https://learn.microsoft.com/en-us/azure/vpn-gateway/tutorial-site-to-site-portal
- **VPN Gateway SKUs**: https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsku

### Networking
- **VNet Peering**: https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview
- **Hub-Spoke topology**: https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
- **NSG Security Rules**: https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview
- **Private Endpoints**: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview

---

## 🎯 Resumen Ultra-Ejecutivo

**Dos arquitecturas recomendadas:**

### Opción 1: Azure Bastion Solo (Individual/Equipos Pequeños)
**3 Pasos Críticos:**
1. ✅ VNet /24 con subnets /27 + NSGs restrictivos
2. ✅ VM sin IP pública + Azure Bastion Standard (SSH native)
3. ✅ Foundry Managed Network + Private Endpoints

**Pros:** 
- Más simple de implementar
- SSH nativo desde CLI
- Ideal para 1-10 usuarios
- Menor complejidad operacional

**Seguridad:** Zero Trust compliant ✅

### Opción 2: VPN Gateway + Bastion (Corporativo/Equipos Grandes)
**4 Pasos Críticos:**
1. ✅ Topología Hub-Spoke con VNets /24 y subnets /27
2. ✅ VPN Gateway (P2S o S2S) para acceso corporativo
3. ✅ Azure Bastion como backup de acceso
4. ✅ Foundry Managed Network + Private Endpoints

**Pros:**
- Acceso directo sin Bastion (más rápido)
- Toda la oficina conectada (S2S)
- Trabajo remoto (P2S)
- Escalable a equipos grandes
- VS Code Remote funciona nativamente

**Contras:**
- Mayor complejidad
- Requiere gestión de VPN clients

**Seguridad:** Enterprise-grade Zero Trust ✅

---

**Recomendación por escenario:**

| Escenario | Solución Recomendada |
|-----------|---------------------|
| 1-5 developers, trabajo remoto | Azure Bastion Solo + SSH tunneling |
| 6-20 developers, trabajo remoto | VPN P2S + Bastion backup |
| Oficina corporativa completa | VPN S2S + Bastion backup |
| Alta seguridad + compliance | VPN S2S + Azure Firewall + Bastion |

**Métodos de acceso disponibles:**
- 🌐 Azure Portal → Bastion web-based
- 💻 Azure CLI → `az network bastion ssh`
- 🔌 SSH tunnel → VS Code Remote, PyCharm
- 🔐 VPN Client → Acceso directo a toda la VNet
- 🖥️ RDP → Windows VMs via Bastion

---

## 📝 Notas Adicionales

### Comparación: Bastion vs VPN

| Característica | Azure Bastion | VPN Gateway |
|----------------|---------------|-------------|
| **Acceso** | Solo via Azure Portal/CLI | Cliente VPN en laptop |
| **Setup** | 30 minutos | 2-3 horas |
| **Costo/mes** | $140 | $145-$360 |
| **Usuarios simultáneos** | Ilimitados | 128 (P2S) o ilimitado (S2S) |
| **Performance** | Buena (navegador) | Excelente (conexión directa) |
| **Firewall corporativo** | Siempre funciona (port 443) | Puede bloquearse (UDP 500/4500) |
| **VS Code Remote** | Via SSH tunnel | Directo (mejor experiencia) |
| **Mantenimiento** | Mínimo | Moderado (certificados, clients) |

### Ventajas de Azure Bastion
- ✅ No requiere VPN client instalado
- ✅ No requiere certificados o configuración de usuarios
- ✅ Funciona desde cualquier navegador moderno
- ✅ SSH nativo desde Azure CLI
- ✅ Copy/paste y file transfer incluidos
- ✅ No expone RDP/SSH ports públicamente
- ✅ Protección DDoS automática

### Ventajas de VPN Gateway
- ✅ Acceso directo a toda la VNet sin Bastion
- ✅ Mejor performance para desarrollo intensivo
- ✅ VS Code Remote funciona sin túneles
- ✅ Kubernetes kubectl funciona directamente
- ✅ Ideal para equipos completos
- ✅ Site-to-Site conecta oficina completa

### Cuándo usar ambos (VPN + Bastion)
- ✅ **Alta disponibilidad**: Si VPN falla, Bastion es backup
- ✅ **Usuarios mixtos**: VPN para developers, Bastion para admins
- ✅ **Compliance**: Doble factor de acceso
- ✅ **Troubleshooting**: Bastion siempre accesible desde portal

### Seguridad adicional
- Azure Bastion elimina la necesidad de Jump Boxes/Bastion Hosts tradicionales
- La VM usa Managed Identity, eliminando la necesidad de almacenar credenciales
- Todos los servicios de Azure se comunican vía Private Endpoints sin salir a Internet público
- Esta configuración cumple con requisitos de Zero Trust y normativas de seguridad empresarial
- NSGs proporcionan segmentación de red a nivel de subnet
- Azure Policy puede aplicar gobernanza automática

### Troubleshooting común

**VPN no conecta:**
```bash
# Verificar estado de VPN Gateway
az network vnet-gateway show --name vpn-foundry-gateway --resource-group rg-foundry-secure-dev

# Ver logs de conexión
az network vnet-gateway list-bgp-peer-status --name vpn-foundry-gateway --resource-group rg-foundry-secure-dev

# Reset VPN Gateway (última opción)
az network vnet-gateway reset --name vpn-foundry-gateway --resource-group rg-foundry-secure-dev
```

**Bastion SSH falla:**
```bash
# Verificar NSG permite tráfico desde AzureBastionSubnet
# Verificar VM tiene SSH habilitado (port 22)
# Verificar SSH key es correcta

# Test desde Azure CLI
az network bastion ssh --name bastion-foundry --resource-group rg-foundry-secure-dev --target-resource-id $VM_ID --auth-type password --username azureuser
```

**Private Endpoint no resuelve:**
```bash
# Verificar DNS privado
nslookup your-endpoint.services.ai.azure.com

# Debe resolver a IP 10.x.x.x, no IP pública
# Si no, verificar Private DNS Zone está linked a VNet
```

---

## 🔄 Próximos Pasos

### Fase 1: Planificación
1. ✅ Decidir arquitectura: Bastion solo vs VPN + Bastion
2. ✅ Definir rangos IP para VNets (usar /24 con subnets /27 - evitar conflictos con red corporativa)
3. ✅ Si usas VPN: Decidir P2S o S2S
4. ✅ Revisar y aprobar arquitectura con equipo de seguridad
5. ✅ Obtener aprobaciones de presupuesto

### Fase 2: Implementación de Red
1. ✅ Crear Resource Groups
2. ✅ Provisionar VNets con segmentación mínima (/24 y /27)
3. ✅ Configurar NSGs con reglas restrictivas
4. ✅ Crear VNet Peering (si aplica Hub-Spoke)
5. ✅ Crear VPN Gateway (si aplica - provisionamiento puede tardar 30-45 min)
6. ✅ Configurar VPN connections (P2S o S2S)

### Fase 3: Compute, Bastion y Herramientas de Desarrollo
1. ✅ Crear VM sin IP pública con Managed Identity
2. ✅ Generar y configurar SSH keys
3. ✅ Crear Azure Bastion Standard
4. ✅ Asignar roles RBAC a VM Managed Identity
5. ✅ Probar acceso via Bastion SSH
6. ✅ Ejecutar script de instalación de herramientas (install-dev-tools.sh)
7. ✅ Configurar estructura de proyecto LangChain
8. ✅ Instalar dependencias Python (requirements.txt)
9. ✅ Configurar Docker y Docker Compose
10. ✅ Validar todas las instalaciones

### Fase 4: Azure AI Foundry
1. ✅ Habilitar Managed Network en Foundry Hub
2. ✅ Crear Private Endpoints para servicios de Foundry
3. ✅ Configurar Private DNS Zones
4. ✅ Validar resolución DNS privada
5. ✅ Probar conectividad desde VM a Foundry

### Fase 5: Desarrollo de Aplicación
1. ✅ Crear estructura de proyecto según template
2. ✅ Configurar variables de entorno (.env)
3. ✅ Implementar código base de aplicación LangChain
4. ✅ Configurar Dockerfile y docker-compose.yml
5. ✅ Ejecutar tests de conexión a Foundry
6. ✅ Build y test de imagen Docker
7. ✅ Validar aplicación localmente
8. ✅ Configurar SSH tunneling para desarrollo remoto
9. ✅ Setup de VS Code Remote SSH
10. ✅ Documentar APIs y endpoints

### Fase 5.5: Configuración de Clientes y Acceso
1. ✅ Distribuir configuración VPN a usuarios (si aplica)
2. ✅ Documentar procedimientos de conexión
3. ✅ Configurar túneles SSH para equipo de desarrollo
4. ✅ Setup de Git y control de versiones
5. ✅ Capacitar al equipo en procedimientos de acceso

### Fase 6: Validación y Monitoreo
1. ✅ Ejecutar checklist de validación de seguridad
2. ✅ Probar todos los métodos de acceso
3. ✅ Configurar Azure Monitor y alertas
4. ✅ Documentar procedimientos operacionales
5. ✅ Crear runbook para troubleshooting

### Fase 7: Optimización (Continuo)
1. ✅ Monitorear uso de IPs en subnets
2. ✅ Revisar logs de acceso y auditoría
3. ✅ Actualizar NSGs según necesidades
4. ✅ Evaluar performance y ajustar recursos
5. ✅ Implementar backup y disaster recovery

### Templates de Automatización

**Opcional: Desplegar con Infrastructure as Code**

```bash
# Azure CLI script básico
./deploy-foundry-network.sh

# O con Bicep/Terraform para reproducibilidad
az deployment group create \
  --resource-group rg-foundry-secure-dev \
  --template-file main.bicep \
  --parameters @parameters.json
```

¿Necesitas templates de Bicep o Terraform para automatizar el despliegue?

---

**Versión:** 3.0  
**Fecha:** Noviembre 2025  
**Autor:** Equipo de Arquitectura Cloud  
**Cambios v3.0:**
- ✅ Ambiente completo de desarrollo con Python 3.11+, Docker, Azure CLI
- ✅ Script de instalación automatizado de herramientas
- ✅ Estructura de proyecto LangChain con FastAPI
- ✅ Dockerfile y docker-compose.yml completos
- ✅ requirements.txt con todas las dependencias
- ✅ Ejemplos de código de aplicación con Azure AI Foundry
- ✅ Guías de desarrollo con VS Code Remote SSH
- ✅ Eliminadas referencias a Jupyter Notebook (enfoque en apps LangChain)
