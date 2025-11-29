# ShopNow - E-commerce Platform

Modern e-commerce platform built with **Hexagonal Architecture** and **Domain-Driven Design (DDD)** principles.

## Architecture

- **Hexagonal Architecture** (Ports & Adapters)
- **Domain-Driven Design** with Bounded Contexts
- **Reactive Programming** with Spring WebFlux
- **Event-Driven Architecture** for inter-context communication
- **CQRS** pattern (Command Query Responsibility Segregation)

## Tech Stack

### Backend
- **Kotlin 2.1.0** - Primary language
- **Java 21** - JVM target
- **Spring Boot 3.4.0** - Framework
- **Spring WebFlux** - Reactive web framework
- **Spring Data R2DBC** - Reactive database access
- **PostgreSQL 17** - Primary database
- **Redis 7** - Caching layer
- **Flyway** - Database migrations

## Bounded Contexts

The system is organized into 10 independent bounded contexts:

1. **Catalog** - Product catalog, categories, inventory
2. **Identity** - User management, authentication, authorization
3. **Shopping** - Shopping cart, wishlist, reviews
4. **Orders** - Order management, order lifecycle
5. **Payment** - Payment processing, transactions
6. **Shipping** - Shipping methods, tracking, delivery
7. **Promotion** - Discounts, coupons, promotional campaigns
8. **Partner** - Affiliates, suppliers
9. **Notification** - User notifications, alerts
10. **Audit** - Audit logging, activity tracking

## Getting Started

### Prerequisites

- Java 21 or higher
- Docker and Docker Compose
- Gradle 8.10+ (wrapper included)

### Quick Start

```bash
# 1. Clone and setup
cp .env.example .env

# 2. Start infrastructure
docker-compose up -d

# 3. Run migrations
./gradlew flywayMigrate

# 4. Run application
./gradlew bootRun
```

### Verify Setup

- Health: http://localhost:8080/actuator/health
- Swagger UI: http://localhost:8080/swagger-ui.html

## Documentation

**Start here**: [ONBOARDING.md](docs/ONBOARDING.md)

Complete documentation:
- [PRD.md](docs/PRD.md) - Product requirements
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Technical architecture
- [HEXAGONAL_ARCHITECTURE.md](docs/HEXAGONAL_ARCHITECTURE.md) - Architecture pattern
- [DDD_GUIDE.md](docs/DDD_GUIDE.md) - Domain-Driven Design guide
- [BOUNDED_CONTEXTS.md](docs/BOUNDED_CONTEXTS.md) - Context details

## Development

```bash
# Run tests
./gradlew test

# Check migrations
./gradlew flywayInfo

# Start with dev tools (pgAdmin, Redis Insight)
docker-compose --profile dev up -d
```

## Roadmap

### Phase 1: Foundation (Current)
- ✅ Architecture documentation
- ✅ Infrastructure setup
- ✅ Dependency configuration
- 🔄 Schema migrations
- 🔄 Project restructuring

### Phase 2: Catalog MVP
- Product management
- Category management
- Inventory tracking

### Phase 3+
- Shopping & Orders
- Reviews & ratings
- Promotions & notifications

---

**Built with ❤️ using Hexagonal Architecture & Domain-Driven Design**
