# 🐳 Docker Setup Guide - ShopNow Backend

This guide explains how to run the ShopNow backend using Docker and Docker Compose.

## 📋 Prerequisites

- **Docker** 20.10+ installed ([Download Docker](https://www.docker.com/get-started))
- **Docker Compose** 2.0+ installed (included with Docker Desktop)
- At least **4GB of RAM** allocated to Docker
- **10GB of free disk space**

Verify installation:
```bash
docker --version
docker-compose --version
```

## 🚀 Quick Start

### 1. Clone and Navigate

```bash
cd ecommerce-kotlin
```

### 2. Start All Services

**Option A: Production mode (backend + infrastructure)**
```bash
docker-compose up -d
```

**Option B: Development mode (with pgAdmin + Redis Insight)**
```bash
docker-compose --profile dev up -d
```

### 3. Check Status

```bash
docker-compose ps
```

You should see all services as **healthy**:
- ✅ `shopnow-backend` - Spring Boot application
- ✅ `shopnow-postgres` - PostgreSQL database
- ✅ `shopnow-redis` - Redis cache

### 4. View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend
docker-compose logs -f postgres
docker-compose logs -f redis
```

### 5. Access Services

Once all services are healthy (may take 1-2 minutes):

| Service | URL | Credentials |
|---------|-----|-------------|
| **Backend API** | http://localhost:8080 | - |
| **Swagger UI** | http://localhost:8080/swagger-ui.html | - |
| **Health Check** | http://localhost:8080/actuator/health | - |
| **pgAdmin** (dev only) | http://localhost:5050 | admin@shopnow.local / admin |
| **Redis Insight** (dev only) | http://localhost:5540 | - |

## 📦 Services Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
│                   (shopnow-network)                      │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Backend    │  │  PostgreSQL  │  │    Redis     │ │
│  │  Port: 8080  │  │  Port: 5432  │  │  Port: 6379  │ │
│  │              │  │              │  │              │ │
│  │ Spring Boot  │──│  Database    │  │  Cache       │ │
│  │   + Flyway   │  │              │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  Dev Tools (--profile dev):                             │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │   pgAdmin    │  │ Redis Insight│                    │
│  │  Port: 5050  │  │  Port: 5540  │                    │
│  └──────────────┘  └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

## 🔧 Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize if needed:

```bash
cp .env.example .env
```

**Default values** (work out of the box):

```env
# Database
DATABASE_NAME=shopnow
DATABASE_USER=shopnow
DATABASE_PASS=shopnow
DATABASE_PORT=5432

# Redis
REDIS_PORT=6379

# Spring Profile
SPRING_PROFILES_ACTIVE=docker
```

### Docker Compose Profiles

| Profile | Services | Usage |
|---------|----------|-------|
| **default** | backend, postgres, redis | Production-like setup |
| **dev** | + pgAdmin, Redis Insight | Development with UI tools |

## 🛠️ Common Commands

### Start Services

```bash
# Start all services (detached mode)
docker-compose up -d

# Start with dev tools
docker-compose --profile dev up -d

# Start and rebuild images
docker-compose up -d --build

# Start specific service
docker-compose up -d backend
```

### Stop Services

```bash
# Stop all services (keeps data)
docker-compose down

# Stop and remove volumes (⚠️ deletes all data)
docker-compose down -v

# Stop specific service
docker-compose stop backend
```

### Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart backend
```

### View Logs

```bash
# Follow all logs
docker-compose logs -f

# Follow backend logs
docker-compose logs -f backend

# Last 100 lines
docker-compose logs --tail=100 backend

# Since timestamp
docker-compose logs --since 2024-01-01T00:00:00 backend
```

### Execute Commands

```bash
# Access backend container shell
docker-compose exec backend sh

# Access PostgreSQL CLI
docker-compose exec postgres psql -U shopnow -d shopnow

# Access Redis CLI
docker-compose exec redis redis-cli

# Run Gradle command in backend
docker-compose exec backend ./gradlew --version
```

### Check Health

```bash
# Service status
docker-compose ps

# Backend health
curl http://localhost:8080/actuator/health

# Database health
docker-compose exec postgres pg_isready -U shopnow

# Redis health
docker-compose exec redis redis-cli ping
```

## 🏗️ Building & Rebuilding

### Rebuild Backend Image

When you change code:

```bash
# Rebuild and restart backend
docker-compose up -d --build backend

# Force rebuild (no cache)
docker-compose build --no-cache backend
docker-compose up -d backend
```

### Clean Build

Remove everything and start fresh:

```bash
# Stop and remove containers, networks, images, volumes
docker-compose down -v --rmi all

# Rebuild from scratch
docker-compose up -d --build
```

## 🗄️ Database Management

### Access Database

**Via pgAdmin (dev profile):**
1. Start with dev profile: `docker-compose --profile dev up -d`
2. Open http://localhost:5050
3. Login: `admin@shopnow.local` / `admin`
4. Add server:
   - Name: `ShopNow Local`
   - Host: `postgres` (service name)
   - Port: `5432`
   - Database: `shopnow`
   - Username: `shopnow`
   - Password: `shopnow`

**Via CLI:**

```bash
# Access PostgreSQL shell
docker-compose exec postgres psql -U shopnow -d shopnow

# List schemas
\dn

# List tables in catalog schema
\dt catalog.*

# Query example
SELECT * FROM catalog.products LIMIT 10;

# Exit
\q
```

### Database Migrations

Flyway migrations run automatically on backend startup. To check status:

```bash
# View backend logs for migration info
docker-compose logs backend | grep -i flyway

# Manually run migrations (if needed)
docker-compose exec backend ./gradlew flywayMigrate

# Check migration status
docker-compose exec backend ./gradlew flywayInfo
```

### Backup & Restore

**Backup:**

```bash
# Backup database to file
docker-compose exec -T postgres pg_dump -U shopnow shopnow > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup specific schema
docker-compose exec -T postgres pg_dump -U shopnow -n catalog shopnow > catalog_backup.sql
```

**Restore:**

```bash
# Restore from backup
docker-compose exec -T postgres psql -U shopnow shopnow < backup.sql
```

## 🐛 Troubleshooting

### Backend not starting

**Check logs:**
```bash
docker-compose logs backend
```

**Common issues:**

1. **Database not ready:**
   - Wait for postgres healthcheck to pass
   - Check: `docker-compose ps` (postgres should be "healthy")

2. **Port already in use:**
   - Change port in `.env`: `PORT=8081`
   - Or stop conflicting service

3. **Build fails:**
   ```bash
   # Clean and rebuild
   docker-compose down
   docker-compose build --no-cache backend
   docker-compose up -d
   ```

### Database connection errors

```bash
# Verify postgres is running
docker-compose ps postgres

# Check postgres logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres pg_isready -U shopnow

# Restart database
docker-compose restart postgres
```

### Out of memory

```bash
# Check container stats
docker stats

# Increase Docker memory limit in Docker Desktop settings
# Recommended: 4GB minimum
```

### Port conflicts

```bash
# Check what's using port 8080
# Windows
netstat -ano | findstr :8080

# macOS/Linux
lsof -i :8080

# Change port in docker-compose.yaml
# ports:
#   - "8081:8080"
```

### Reset everything

```bash
# Nuclear option - delete everything
docker-compose down -v --rmi all
docker system prune -a --volumes

# Start fresh
docker-compose up -d --build
```

## 📊 Monitoring

### Container Resource Usage

```bash
# Real-time stats
docker stats

# Specific container
docker stats shopnow-backend
```

### Health Checks

```bash
# Backend health (detailed)
curl http://localhost:8080/actuator/health | jq

# Prometheus metrics
curl http://localhost:8080/actuator/prometheus
```

### Database Connections

```bash
# Active connections
docker-compose exec postgres psql -U shopnow -d shopnow -c "SELECT * FROM pg_stat_activity;"

# Connection count
docker-compose exec postgres psql -U shopnow -d shopnow -c "SELECT count(*) FROM pg_stat_activity;"
```

## 🔒 Security Notes

### Production Checklist

Before deploying to production:

- [ ] Change all default passwords in `.env`
- [ ] Use strong, random `JWT_SECRET`
- [ ] Disable dev profile (`pgAdmin`, `Redis Insight`)
- [ ] Use environment-specific secrets
- [ ] Enable HTTPS/TLS
- [ ] Restrict CORS origins
- [ ] Review and harden PostgreSQL configuration
- [ ] Enable Redis authentication
- [ ] Use secrets management (Docker Secrets, Vault, etc.)

### Non-root User

The backend container runs as non-root user `shopnow:shopnow` (UID/GID 1001) for security.

## 📝 Tips & Best Practices

1. **Always use `-d` flag** for detached mode in production
2. **Check logs regularly** with `docker-compose logs -f`
3. **Use volumes for data persistence** (already configured)
4. **Regular backups** of database volumes
5. **Monitor resource usage** with `docker stats`
6. **Keep images updated** with `docker-compose pull`
7. **Clean unused resources** with `docker system prune`

## 🆘 Getting Help

If you encounter issues:

1. Check logs: `docker-compose logs -f backend`
2. Verify all services are healthy: `docker-compose ps`
3. Check this troubleshooting guide
4. Review `CLAUDE.md` for architecture details
5. Create an issue on GitHub

## 📚 Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Spring Boot Docker Guide](https://spring.io/guides/topicals/spring-boot-docker/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [Redis Docker Hub](https://hub.docker.com/_/redis)

---

**Happy Coding! 🚀**
