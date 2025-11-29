# ShopNow - Guía de Troubleshooting

Esta guía cubre problemas comunes y sus soluciones para **Windows**, **Mac** y **Linux**.

## Tabla de Contenidos
- [Problemas con Java](#problemas-con-java)
- [Problemas con Docker](#problemas-con-docker)
- [Problemas con la Base de Datos](#problemas-con-la-base-de-datos)
- [Problemas con Gradle](#problemas-con-gradle)
- [Problemas con la Aplicación](#problemas-con-la-aplicación)
- [Problemas Específicos por SO](#problemas-específicos-por-so)

---

## Problemas con Java

### ❌ Error: `JAVA_HOME not set`

**Windows:**
```powershell
# Verificar si Java está instalado
java -version

# Si está instalado pero JAVA_HOME no está configurado:
# 1. Buscar la ubicación de Java
where java

# 2. Configurar JAVA_HOME
setx JAVA_HOME "C:\Program Files\Microsoft\jdk-21.0.8.9-hotspot"
setx PATH "%PATH%;%JAVA_HOME%\bin"

# 3. Reiniciar PowerShell/CMD
```

**Mac:**
```bash
# Verificar si Java está instalado
java -version

# Encontrar JAVA_HOME
/usr/libexec/java_home -V

# Agregar a ~/.zshrc o ~/.bash_profile
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 21)' >> ~/.zshrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.zshrc

# Recargar configuración
source ~/.zshrc
```

**Linux:**
```bash
# Verificar Java
java -version

# Encontrar JAVA_HOME
update-alternatives --list java

# Agregar a ~/.bashrc o ~/.profile
echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> ~/.bashrc
echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> ~/.bashrc

# Recargar
source ~/.bashrc
```

### ❌ Error: `Unsupported class file major version`

**Causa:** Versión incorrecta de Java

**Solución:**
```bash
# Verificar versión de Java
java -version

# Debe ser Java 21. Si no:
# - Windows: Desinstalar versión antigua y reinstalar Java 21
# - Mac: brew install openjdk@21
# - Linux: sudo apt install openjdk-21-jdk
```

---

## Problemas con Docker

### ❌ Error: `Cannot connect to the Docker daemon`

**Windows:**
1. Abrir Docker Desktop
2. Esperar a que el ícono en la bandeja del sistema se vuelva verde
3. Verificar en PowerShell:
```powershell
docker ps
```

**Mac:**
1. Abrir Docker Desktop desde Applications
2. Esperar a que esté completamente iniciado
3. Verificar:
```bash
docker ps
```

**Linux:**
```bash
# Iniciar Docker
sudo systemctl start docker

# Habilitar Docker al inicio
sudo systemctl enable docker

# Agregar tu usuario al grupo docker (para no usar sudo)
sudo usermod -aG docker $USER
newgrp docker

# Verificar
docker ps
```

### ❌ Error: `port is already allocated`

**Windows:**
```powershell
# Encontrar proceso usando el puerto (ej: 8080)
netstat -ano | findstr :8080

# Matar el proceso (reemplazar PID con el número de proceso)
taskkill //F //PID <PID>

# O cambiar el puerto en docker-compose.yaml o application.yml
```

**Mac/Linux:**
```bash
# Encontrar proceso usando el puerto
lsof -i :8080

# Matar el proceso
kill -9 <PID>

# O usando fuser (Linux)
sudo fuser -k 8080/tcp
```

### ❌ Error: `docker-compose: command not found`

**Windows:**
- Docker Compose viene integrado en Docker Desktop
- Si falta, reinstalar Docker Desktop

**Mac:**
```bash
# Docker Compose v2 (plugin)
docker compose version

# Si no funciona, instalar:
brew install docker-compose
```

**Linux:**
```bash
# Docker Compose v2 viene con docker-compose-plugin
sudo apt install docker-compose-plugin

# Verificar
docker compose version
```

### ❌ Error: `Error response from daemon: Conflict`

**Solución:**
```bash
# Detener y eliminar contenedores conflictivos
docker-compose down

# Si persiste, eliminar contenedores manualmente
docker ps -a
docker rm -f <container_id>

# Limpiar volúmenes huérfanos
docker volume prune
```

---

## Problemas con la Base de Datos

### ❌ Error: `Connection refused` al conectar a PostgreSQL

**Verificar que PostgreSQL esté corriendo:**
```bash
docker-compose ps
```

**Si no está corriendo:**
```bash
docker-compose up -d postgres
```

**Verificar logs:**
```bash
docker-compose logs postgres
```

**Verificar conexión:**
```bash
docker exec -it shopnow-postgres psql -U shopnow -d shopnow
```

### ❌ Error: `password authentication failed`

**Solución:**
```bash
# 1. Detener contenedores
docker-compose down

# 2. Eliminar volumen de PostgreSQL
docker volume rm ecommerce-kotlin_postgres_data

# 3. Volver a iniciar
docker-compose up -d

# Las credenciales por defecto son:
# Usuario: shopnow
# Password: shopnow
# Database: shopnow
```

### ❌ Error: `Flyway migration failed`

**Ver logs de Flyway:**
```bash
# Ver últimos logs de la aplicación
docker-compose logs app | grep -i flyway
```

**Resetear migraciones (⚠️ BORRARÁ DATOS):**
```bash
# 1. Conectarse a PostgreSQL
docker exec -it shopnow-postgres psql -U shopnow -d shopnow

# 2. Eliminar tabla de historial de Flyway
DROP TABLE IF EXISTS catalog.flyway_schema_history CASCADE;

# 3. Eliminar esquemas
DROP SCHEMA IF EXISTS catalog, identity, shopping, orders, payment, shipping, promotion, partner, notification, audit, events CASCADE;

# 4. Salir (\q) y reiniciar la aplicación
```

### ❌ Error: `relation does not exist`

**Causa:** La tabla no existe en el esquema correcto

**Verificar esquemas:**
```bash
docker exec shopnow-postgres psql -U shopnow -d shopnow -c "\dn"
```

**Verificar tablas en un esquema:**
```bash
docker exec shopnow-postgres psql -U shopnow -d shopnow -c "\dt catalog.*"
```

**Si faltan tablas, ejecutar migraciones:**
```bash
./gradlew flywayMigrate
# o reiniciar la aplicación (las migraciones se ejecutan al inicio)
```

---

## Problemas con Gradle

### ❌ Error: `Could not resolve dependencies`

**Windows:**
```powershell
# Limpiar caché de Gradle
.\gradlew.bat clean

# Eliminar caché de dependencias
Remove-Item -Recurse -Force $env:USERPROFILE\.gradle\caches

# Volver a descargar dependencias
.\gradlew.bat build --refresh-dependencies
```

**Mac/Linux:**
```bash
# Limpiar proyecto
./gradlew clean

# Eliminar caché
rm -rf ~/.gradle/caches

# Refrescar dependencias
./gradlew build --refresh-dependencies
```

### ❌ Error: `Gradle daemon disappeared unexpectedly`

**Solución:**
```bash
# Detener todos los daemons de Gradle
./gradlew --stop

# Aumentar memoria (crear/editar gradle.properties)
echo "org.gradle.jvmargs=-Xmx2048m -XX:MaxMetaspaceSize=512m" >> gradle.properties

# Volver a compilar
./gradlew build
```

### ❌ Error: `Permission denied` (Mac/Linux)

```bash
# Dar permisos de ejecución a gradlew
chmod +x gradlew

# Ejecutar
./gradlew build
```

---

## Problemas con la Aplicación

### ❌ Error: `Port 8080 was already in use`

**Windows:**
```powershell
# Encontrar proceso
netstat -ano | findstr :8080

# Matar proceso
taskkill //F //PID <PID>
```

**Mac:**
```bash
# Encontrar y matar proceso
lsof -ti:8080 | xargs kill -9
```

**Linux:**
```bash
# Opción 1
sudo fuser -k 8080/tcp

# Opción 2
sudo lsof -ti:8080 | xargs kill -9
```

**O cambiar el puerto:**
```yaml
# En application.yml
server:
  port: 8081
```

### ❌ Error: `Failed to bind properties under 'spring.datasource.url'`

**Verificar docker-compose:**
```bash
docker-compose ps
# PostgreSQL debe estar UP y (healthy)
```

**Verificar application.yml:**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/shopnow
    username: shopnow
    password: shopnow
```

**Probar conexión manual:**
```bash
docker exec -it shopnow-postgres psql -U shopnow -d shopnow
```

### ❌ Error: `NoSuchBeanDefinitionException`

**Causa:** Falta un @Repository, @Service o @Component

**Solución:**
1. Verificar que la clase tenga la anotación correcta:
   - `@Repository` para repositorios
   - `@Service` para servicios
   - `@Component` para componentes genéricos
   - `@RestController` para controllers

2. Verificar que el package esté bajo `com.shopnow`

3. Agregar `@ComponentScan` si es necesario en `ShopNowApplication.kt`

### ❌ Error: `R2dbcDataIntegrityViolationException`

**Causa:** Violación de constraint (unique, foreign key, etc.)

**Ejemplos comunes:**
```
duplicate key value violates unique constraint "uq_product_sku"
→ El SKU ya existe

violates foreign key constraint "products_category_id_fkey"
→ El category_id no existe

violates check constraint "products_price_check"
→ El precio es negativo
```

**Solución:**
- Verificar que los datos cumplan las reglas de negocio
- Verificar que las entidades referenciadas existan

---

## Problemas Específicos por SO

### 🪟 Windows

#### Error: `The system cannot find the path specified`

**Causa:** Rutas con espacios o caracteres especiales

**Solución:**
```powershell
# Usar rutas entre comillas
cd "C:\Users\My Name\projects\ecommerce-kotlin"

# O usar rutas cortas
cd C:\Users\MYNAME~1\projects\ecommerce-kotlin
```

#### Error: PowerShell `execution policy`

```powershell
# Cambiar política de ejecución
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Docker Desktop no inicia

1. Verificar que la virtualización esté habilitada en BIOS
2. Verificar que Hyper-V esté habilitado:
```powershell
# Como administrador
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```
3. Reiniciar Windows

### 🍎 Mac

#### Error: `xcrun: error: invalid active developer path`

**Causa:** Faltan herramientas de línea de comandos de Xcode

**Solución:**
```bash
xcode-select --install
```

#### Error: `Permission denied` en Docker

```bash
# Reiniciar Docker Desktop completamente
killall Docker && open /Applications/Docker.app

# Verificar permisos
ls -la /var/run/docker.sock
```

#### Error: `Port 5432 already in use` (PostgreSQL local)

```bash
# Si tienes PostgreSQL instalado localmente:
# Opción 1: Detener PostgreSQL local
brew services stop postgresql

# Opción 2: Cambiar puerto en docker-compose.yaml
ports:
  - "5433:5432"  # Usar puerto 5433 en el host
```

### 🐧 Linux

#### Error: `docker: Got permission denied`

```bash
# Agregar usuario al grupo docker
sudo usermod -aG docker $USER

# Aplicar cambios (o cerrar sesión y volver a entrar)
newgrp docker

# Verificar
docker ps
```

#### Error: `Cannot connect to X server`

**Causa:** Intentando abrir aplicaciones gráficas vía SSH

**Solución:**
```bash
# Conectarse con X11 forwarding
ssh -X user@server

# O usar solo CLI sin aplicaciones gráficas
```

#### Error: `No space left on device`

```bash
# Limpiar imágenes de Docker no usadas
docker system prune -a

# Limpiar volúmenes no usados
docker volume prune

# Ver uso de espacio
df -h
du -sh ~/.gradle
```

---

## Logs Útiles para Debugging

### Ver logs de la aplicación
```bash
# Con Gradle
./gradlew bootRun

# Con Docker (si se containeriza la app)
docker-compose logs -f app
```

### Ver logs de PostgreSQL
```bash
docker-compose logs -f postgres
```

### Ver logs de Redis
```bash
docker-compose logs -f redis
```

### Ver logs de todos los servicios
```bash
docker-compose logs -f
```

### Nivel de log más detallado

**En application.yml:**
```yaml
logging:
  level:
    root: DEBUG
    com.shopnow: TRACE
    org.springframework: DEBUG
```

---

## Recursos Adicionales

- [Documentación oficial de Spring Boot](https://docs.spring.io/spring-boot/docs/current/reference/html/)
- [Documentación de Docker](https://docs.docker.com/)
- [Documentación de PostgreSQL](https://www.postgresql.org/docs/)
- [Kotlin Coroutines](https://kotlinlang.org/docs/coroutines-overview.html)

---

## ¿Aún tienes problemas?

1. Verifica los logs completos
2. Busca el error en Google/Stack Overflow
3. Crea un issue en el repositorio con:
   - Sistema operativo y versión
   - Versión de Java
   - Logs completos del error
   - Pasos para reproducir el problema
