# ShopNow - Guía de Configuración del Entorno

Esta guía te ayudará a configurar el entorno de desarrollo para ShopNow en **Windows**, **Mac** y **Linux**.

## Tabla de Contenidos
- [Requisitos Previos](#requisitos-previos)
- [Instalación por Sistema Operativo](#instalación-por-sistema-operativo)
- [Configuración del Proyecto](#configuración-del-proyecto)
- [Ejecutar la Aplicación](#ejecutar-la-aplicación)
- [Verificar la Instalación](#verificar-la-instalación)
- [Acceder a las Herramientas](#acceder-a-las-herramientas)

---

## Requisitos Previos

Antes de comenzar, necesitas tener instalado:

1. **Java 21** (OpenJDK o Oracle JDK)
2. **Docker** y **Docker Compose**
3. **Git**
4. **(Opcional)** IntelliJ IDEA o tu IDE preferido

---

## Instalación por Sistema Operativo

### 🪟 Windows

#### 1. Instalar Java 21

**Opción A: Usando Chocolatey**
```powershell
# Instalar Chocolatey si no lo tienes
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Instalar OpenJDK 21
choco install microsoft-openjdk21 -y
```

**Opción B: Instalación Manual**
1. Descargar desde: https://learn.microsoft.com/en-us/java/openjdk/download#openjdk-21
2. Ejecutar el instalador
3. Agregar a PATH:
   ```powershell
   setx JAVA_HOME "C:\Program Files\Microsoft\jdk-21.0.8.9-hotspot"
   setx PATH "%PATH%;%JAVA_HOME%\bin"
   ```

#### 2. Instalar Docker Desktop

1. Descargar desde: https://www.docker.com/products/docker-desktop/
2. Ejecutar el instalador
3. Reiniciar el sistema
4. Abrir Docker Desktop y esperar a que inicie

#### 3. Instalar Git

**Usando Chocolatey:**
```powershell
choco install git -y
```

**Manual:**
- Descargar desde: https://git-scm.com/download/win

#### 4. Verificar Instalación

```powershell
# Verificar Java
java -version
# Debe mostrar: openjdk version "21.0.x"

# Verificar Docker
docker --version
docker-compose --version

# Verificar Git
git --version
```

---

### 🍎 Mac

#### 1. Instalar Homebrew (si no lo tienes)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Instalar Java 21

```bash
# Instalar OpenJDK 21
brew install openjdk@21

# Crear symlink
sudo ln -sfn $(brew --prefix)/opt/openjdk@21/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk

# Agregar a PATH (añadir a ~/.zshrc o ~/.bash_profile)
echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### 3. Instalar Docker Desktop

```bash
# Opción A: Usando Homebrew
brew install --cask docker

# Opción B: Manual
# Descargar desde: https://www.docker.com/products/docker-desktop/
```

Después de instalar, abre Docker Desktop desde Applications.

#### 4. Instalar Git

```bash
brew install git
```

#### 5. Verificar Instalación

```bash
# Verificar Java
java -version

# Verificar Docker
docker --version
docker-compose --version

# Verificar Git
git --version
```

---

### 🐧 Linux (Ubuntu/Debian)

#### 1. Instalar Java 21

```bash
# Actualizar repositorios
sudo apt update

# Instalar OpenJDK 21
sudo apt install openjdk-21-jdk -y

# Verificar instalación
java -version
```

#### 2. Instalar Docker y Docker Compose

```bash
# Desinstalar versiones antiguas
sudo apt remove docker docker-engine docker.io containerd runc

# Instalar dependencias
sudo apt update
sudo apt install ca-certificates curl gnupg lsb-release

# Agregar clave GPG oficial de Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Agregar repositorio de Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker Engine
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

# Agregar tu usuario al grupo docker (para no usar sudo)
sudo usermod -aG docker $USER
newgrp docker

# Iniciar Docker
sudo systemctl start docker
sudo systemctl enable docker
```

#### 3. Instalar Git

```bash
sudo apt install git -y
```

#### 4. Verificar Instalación

```bash
# Verificar Java
java -version

# Verificar Docker
docker --version
docker compose version

# Verificar Git
git --version
```

---

## Configuración del Proyecto

### 1. Clonar el Repositorio

```bash
git clone <url-del-repositorio>
cd ecommerce-kotlin
```

### 2. Crear Archivo de Configuración de Entorno

```bash
# Copiar el archivo de ejemplo
cp .env.example .env

# Editar el archivo .env con tus configuraciones (opcional)
# nano .env  # Linux/Mac
# notepad .env  # Windows
```

### 3. Iniciar la Infraestructura (PostgreSQL y Redis)

```bash
# Iniciar los contenedores en background
docker-compose up -d

# Verificar que los contenedores estén corriendo
docker-compose ps
```

**Salida esperada:**
```
NAME               IMAGE            STATUS
shopnow-postgres   postgres:17      Up (healthy)
shopnow-redis      redis:7-alpine   Up (healthy)
```

### 4. Verificar la Conexión a la Base de Datos

```bash
# Conectarse a PostgreSQL
docker exec -it shopnow-postgres psql -U shopnow -d shopnow

# Dentro de psql, verificar los esquemas:
\dn
```

**Deberías ver:**
```
     Name     |  Owner
--------------+---------
 audit        | shopnow
 catalog      | shopnow
 events       | shopnow
 identity     | shopnow
 ...
```

Salir con `\q`

---

## Ejecutar la Aplicación

### Usando Gradle Wrapper (Recomendado)

**Windows:**
```powershell
.\gradlew.bat bootRun
```

**Mac/Linux:**
```bash
./gradlew bootRun
```

### Usando IntelliJ IDEA

1. Abrir el proyecto en IntelliJ IDEA
2. Esperar a que Gradle sincronice las dependencias
3. Buscar el archivo `ShopNowApplication.kt`
4. Click derecho → Run 'ShopNowApplicationKt'

### Compilar el Proyecto (Sin Ejecutar)

```bash
# Windows
.\gradlew.bat build

# Mac/Linux
./gradlew build
```

---

## Verificar la Instalación

Una vez que la aplicación esté corriendo, verifica:

### 1. API Funcionando

```bash
# Verificar el health endpoint
curl http://localhost:8080/actuator/health
```

**Salida esperada:**
```json
{
  "status": "UP"
}
```

### 2. Swagger UI (Documentación API)

Abrir en el navegador:
```
http://localhost:8080/swagger-ui.html
```

### 3. Verificar PostgreSQL

```bash
# Listar tablas del contexto Catalog
docker exec shopnow-postgres psql -U shopnow -d shopnow -c "\dt catalog.*"
```

### 4. Verificar Redis

```bash
# Conectarse a Redis
docker exec -it shopnow-redis redis-cli

# Dentro de redis-cli, probar:
PING
```

**Debería responder:** `PONG`

Salir con `exit`

---

## Acceder a las Herramientas

### pgAdmin (Administrador de PostgreSQL)

**Solo en modo desarrollo:**
```bash
docker-compose --profile dev up -d
```

Luego abrir: http://localhost:5050

**Credenciales:**
- Email: `admin@shopnow.com`
- Password: `admin`

**Configurar servidor:**
- Host: `postgres` (nombre del servicio)
- Port: `5432`
- Database: `shopnow`
- Username: `shopnow`
- Password: `shopnow`

### Redis Insight (Administrador de Redis)

**Solo en modo desarrollo:**
```bash
docker-compose --profile dev up -d
```

Luego abrir: http://localhost:8001

---

## Comandos Útiles

### Docker

```bash
# Ver logs de todos los servicios
docker-compose logs -f

# Ver logs de un servicio específico
docker-compose logs -f postgres

# Detener todos los servicios
docker-compose down

# Detener y eliminar volúmenes (⚠️ BORRARÁ LOS DATOS)
docker-compose down -v

# Reiniciar un servicio
docker-compose restart postgres
```

### Gradle

```bash
# Limpiar el proyecto
./gradlew clean

# Compilar sin tests
./gradlew build -x test

# Ejecutar tests
./gradlew test

# Ver dependencias
./gradlew dependencies
```

### Base de Datos

```bash
# Backup de la base de datos
docker exec shopnow-postgres pg_dump -U shopnow shopnow > backup.sql

# Restaurar backup
docker exec -i shopnow-postgres psql -U shopnow shopnow < backup.sql

# Ver esquemas creados
docker exec shopnow-postgres psql -U shopnow -d shopnow -c "\dn"

# Ver tablas de un esquema
docker exec shopnow-postgres psql -U shopnow -d shopnow -c "\dt catalog.*"
```

---

## Detener el Entorno

```bash
# Detener sin eliminar datos
docker-compose stop

# Detener y eliminar contenedores (los datos persisten en volúmenes)
docker-compose down

# Detener, eliminar contenedores Y datos
docker-compose down -v
```

---

## Próximos Pasos

1. **Lee la [Guía de Arquitectura](./ARCHITECTURE.md)** para entender la estructura del proyecto
2. **Consulta [Troubleshooting](./TROUBLESHOOTING.md)** si encuentras problemas
3. **Revisa [DDD Guide](./DDD_GUIDE.md)** para entender los patrones DDD usados
4. **Lee [NEXT_STEPS.md](./NEXT_STEPS.md)** para ver el roadmap de desarrollo

---

## Soporte

Si encuentras problemas, consulta:
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Problemas comunes y soluciones
- Issues del proyecto en GitHub
