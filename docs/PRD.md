# Product Requirements Context (PRC)

## 1. Executive Summary

**Project Name**: ShopNow - E-commerce Platform
**Vision**: Construir una plataforma de e-commerce escalable, moderna y mantenible usando principios de arquitectura hexagonal y Domain-Driven Design (DDD).

**Filosofía de desarrollo**: Iterativa y evolutiva
- Lanzar rápido con funcionalidad core
- Iterar basado en feedback
- Escalar de forma incremental por bounded contexts
- Priorizar mantenibilidad y extensibilidad

## 2. Business Context

### 2.1 Objetivo del Negocio
Crear una plataforma de e-commerce que permita:
- Gestión de productos y catálogos
- Experiencia de compra completa para usuarios
- Procesamiento de pedidos
- Gestión de inventario
- Sistema de descuentos y promociones
- Programa de afiliados

### 2.2 Crecimiento Incremental
A diferencia de esquemas monolíticos tipo Shopify, vamos a crecer por bounded contexts:

**Fase 1 - MVP (Actual)**:
- Catálogo de Productos
- Usuarios básicos
- Carrito de compras

**Fase 2 - Core E-commerce**:
- Sistema de pedidos
- Procesamiento de pagos
- Gestión de inventario

**Fase 3 - Engagement**:
- Reviews y ratings
- Wishlist
- Notificaciones

**Fase 4 - Business Intelligence**:
- Programa de afiliados
- Promociones y cupones
- Analytics y reportes

## 3. Technical Architecture

### 3.1 Architectural Principles

#### Hexagonal Architecture (Ports & Adapters)
```
┌─────────────────────────────────────────────────────────┐
│                    Infrastructure                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   REST API  │  │   GraphQL   │  │   Events    │     │
│  │  (WebFlux)  │  │             │  │  Publisher  │     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘     │
│         │ Input Port     │                 │            │
├─────────┼────────────────┼─────────────────┼────────────┤
│         ▼                ▼                 ▼            │
│  ┌──────────────────────────────────────────────────┐  │
│  │           Application Layer (Use Cases)          │  │
│  │                                                   │  │
│  │  - Command Handlers (Sync/Async)                 │  │
│  │  - Query Handlers                                │  │
│  │  - Event Handlers                                │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      │                                  │
│  ┌───────────────────▼──────────────────────────────┐  │
│  │              Domain Layer                        │  │
│  │                                                   │  │
│  │  - Aggregates                                    │  │
│  │  - Entities                                      │  │
│  │  - Value Objects                                 │  │
│  │  - Domain Events                                 │  │
│  │  - Domain Services                               │  │
│  │  - Repository Interfaces (Output Ports)          │  │
│  └───────────────────┬──────────────────────────────┘  │
│                      │ Output Port                      │
├──────────────────────┼──────────────────────────────────┤
│         ┌────────────▼──────────┐                       │
│         │   Infrastructure      │                       │
│  ┌──────┴──────┐  ┌────────────┴─────┐                │
│  │  R2DBC      │  │     JDBC         │                 │
│  │  (Async)    │  │    (Sync)        │                 │
│  └─────────────┘  └──────────────────┘                 │
│  ┌─────────────┐  ┌──────────────────┐                │
│  │   Redis     │  │  Event Store     │                 │
│  │   Cache     │  │  (PostgreSQL)    │                 │
│  └─────────────┘  └──────────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

#### Domain-Driven Design (DDD)

**Bounded Contexts** identificados:

1. **Catalog Context** (Catálogo)
   - Products
   - Categories
   - ProductImages
   - Inventory

2. **Identity & Access Context** (IAM)
   - Users
   - Admins
   - UserRoles
   - Authentication/Authorization

3. **Shopping Context** (Compras)
   - Cart
   - Wishlist
   - Reviews
   - Feedback

4. **Order Management Context** (Pedidos)
   - Orders
   - OrderItems
   - Returns
   - OrderTaxes

5. **Payment Context** (Pagos)
   - PaymentMethods
   - Transactions
   - Refunds

6. **Shipping Context** (Envíos)
   - Addresses
   - ShippingMethods
   - ShippingDetails

7. **Promotion Context** (Promociones)
   - Discounts
   - Coupons
   - PromoBanners

8. **Partner Context** (Afiliados y Proveedores)
   - Affiliates
   - Suppliers
   - AffiliateSales

9. **Notification Context** (Notificaciones)
   - Notifications
   - Communication preferences

10. **Audit Context** (Auditoría)
    - AuditLogs
    - Activity tracking

### 3.2 Technology Stack

#### Backend Framework
- **Spring Boot 3.4+** - Framework principal
- **Spring WebFlux** - Reactive web framework para endpoints síncronos y asíncronos
- **Kotlin 2.1+** - Lenguaje principal
- **Java 21** - JVM target

#### Database Layer
- **PostgreSQL 17** - Base de datos principal
- **R2DBC** - Driver reactivo para operaciones asíncronas
- **JDBC** - Driver tradicional para operaciones síncronas cuando sea necesario
- **Flyway** - Migraciones de base de datos
- **Redis** - Cache y sesiones

#### Messaging & Events
- **Spring Cloud Stream** - Abstracción de mensajería
- **Kafka** o **RabbitMQ** - Event broker (a definir)
- **Domain Events** - Eventos internos del dominio

#### Testing
- **JUnit 5** - Framework de testing
- **Testcontainers** - Testing con contenedores
- **Kotest** - Testing idiomático para Kotlin
- **MockK** - Mocking para Kotlin

#### DevOps
- **Docker & Docker Compose** - Containerización
- **Gradle (Kotlin DSL)** - Build tool

### 3.3 Data Architecture

#### Schema Organization
Cada bounded context tendrá su propio schema en PostgreSQL:

```sql
-- Catalog Context
CREATE SCHEMA catalog;

-- Identity & Access Context
CREATE SCHEMA identity;

-- Shopping Context
CREATE SCHEMA shopping;

-- Order Management Context
CREATE SCHEMA orders;

-- Payment Context
CREATE SCHEMA payment;

-- Shipping Context
CREATE SCHEMA shipping;

-- Promotion Context
CREATE SCHEMA promotion;

-- Partner Context
CREATE SCHEMA partner;

-- Notification Context
CREATE SCHEMA notification;

-- Audit Context
CREATE SCHEMA audit;
```

#### Migration Strategy
- Migraciones organizadas por schema y contexto
- Convención de nombres: `V{version}__{context}__{description}.sql`
- Ejemplo: `V2__catalog__create_products_table.sql`

### 3.4 Communication Patterns

#### Synchronous Communication
- REST API con WebFlux para operaciones de lectura/escritura directas
- CQRS pattern: Commands y Queries separados
- Response reactivo con Mono/Flux

#### Asynchronous Communication
- Domain Events para comunicación entre bounded contexts
- Event-driven architecture para procesos de larga duración
- Eventual consistency entre contextos

#### Cross-Context Communication
```
Catalog Context
    │
    ├─(Event)─> Order Context    // ProductPriceChanged
    │
    └─(Event)─> Notification      // ProductOutOfStock

Order Context
    │
    ├─(Event)─> Payment           // OrderCreated
    ├─(Event)─> Shipping          // OrderConfirmed
    ├─(Event)─> Inventory         // InventoryReserved
    └─(Event)─> Notification      // OrderStatusChanged
```

## 4. Project Structure

### 4.1 Directory Organization

```
src/main/kotlin/com/shopnow/
├── shared/                          # Shared kernel
│   ├── domain/
│   │   ├── AggregateRoot.kt
│   │   ├── DomainEvent.kt
│   │   ├── ValueObject.kt
│   │   └── Entity.kt
│   ├── application/
│   │   ├── UseCase.kt
│   │   └── EventPublisher.kt
│   └── infrastructure/
│       ├── persistence/
│       └── messaging/
│
├── catalog/                         # Catalog Bounded Context
│   ├── domain/
│   │   ├── model/
│   │   │   ├── Product.kt          # Aggregate Root
│   │   │   ├── Category.kt         # Entity
│   │   │   ├── Money.kt            # Value Object
│   │   │   └── ProductImage.kt
│   │   ├── repository/
│   │   │   └── ProductRepository.kt # Port (interface)
│   │   ├── event/
│   │   │   ├── ProductCreated.kt
│   │   │   └── ProductPriceChanged.kt
│   │   └── service/
│   │       └── ProductDomainService.kt
│   ├── application/
│   │   ├── command/
│   │   │   ├── CreateProductCommand.kt
│   │   │   └── CreateProductHandler.kt
│   │   ├── query/
│   │   │   ├── GetProductQuery.kt
│   │   │   └── GetProductHandler.kt
│   │   └── event/
│   │       └── ProductEventHandler.kt
│   └── infrastructure/
│       ├── adapter/
│       │   ├── input/
│       │   │   └── rest/
│       │   │       └── ProductController.kt
│       │   └── output/
│       │       ├── persistence/
│       │       │   ├── ProductEntity.kt        # JPA/R2DBC Entity
│       │       │   ├── ProductMapper.kt
│       │       │   └── ProductRepositoryAdapter.kt # Implementation
│       │       └── messaging/
│       │           └── ProductEventPublisher.kt
│       └── config/
│           └── CatalogConfiguration.kt
│
├── identity/                        # Identity & Access Context
│   └── [same structure]
│
├── shopping/                        # Shopping Context
│   └── [same structure]
│
├── orders/                          # Order Management Context
│   └── [same structure]
│
└── [other contexts...]
```

### 4.2 Configuration Files Structure

```
src/main/resources/
├── application.yml                  # Main configuration
├── application-dev.yml              # Development profile
├── application-prod.yml             # Production profile
└── db/
    └── migration/
        ├── catalog/
        │   ├── V2__catalog__create_schema.sql
        │   ├── V3__catalog__create_products.sql
        │   └── V4__catalog__create_categories.sql
        ├── identity/
        │   ├── V2__identity__create_schema.sql
        │   └── V3__identity__create_users.sql
        └── [other contexts...]
```

## 5. Development Roadmap

### Phase 1: Foundation & Infrastructure (Current Sprint)
- [x] Analyze current architecture
- [ ] Create comprehensive documentation
- [ ] Update all dependencies
- [ ] Setup Docker Compose with PostgreSQL + Redis
- [ ] Restructure project to hexagonal architecture
- [ ] Implement shared kernel
- [ ] Create schema-based migrations

### Phase 2: Catalog Context (MVP)
- [ ] Implement Product aggregate
- [ ] Create Product REST API (WebFlux)
- [ ] Setup R2DBC for async queries
- [ ] Implement caching with Redis
- [ ] Create domain events
- [ ] Write integration tests

### Phase 3: Identity & Shopping Contexts
- [ ] User management
- [ ] Authentication/Authorization
- [ ] Shopping cart functionality
- [ ] Cross-context events

### Phase 4: Order & Payment Flow
- [ ] Order processing (async)
- [ ] Payment integration
- [ ] Event-driven order flow
- [ ] Transaction handling

### Phase 5: Advanced Features
- [ ] Promotions & discounts
- [ ] Notifications
- [ ] Analytics
- [ ] Affiliate program

## 6. Success Criteria

### 6.1 Technical Metrics
- Clean separation between bounded contexts
- No circular dependencies between contexts
- 80%+ test coverage per context
- API response time < 200ms (p95)
- Support for 1000+ concurrent users

### 6.2 Development Metrics
- New developer onboarding < 2 days
- Clear documentation for all contexts
- Consistent coding patterns across contexts
- Easy to add new features without touching existing code

### 6.3 Business Metrics
- Support multiple product categories
- Handle complete purchase flow
- Process orders asynchronously
- Reliable inventory management
- Scalable to handle growth

## 7. Non-Functional Requirements

### 7.1 Performance
- Async processing for long-running operations
- Caching strategy with Redis
- Connection pooling
- Reactive streams for high throughput

### 7.2 Scalability
- Horizontal scaling capability
- Event-driven architecture for decoupling
- Schema-per-context for database scaling
- Stateless application design

### 7.3 Maintainability
- Clear bounded context boundaries
- Comprehensive documentation
- Consistent coding standards
- Automated testing strategy

### 7.4 Security
- Input validation at boundaries
- Authentication & authorization
- Sensitive data encryption
- Audit logging

## 8. Documentation Strategy

All documentation will be maintained in `/docs`:

- `PRD.md` - This document (Product Requirements Context)
- `ARCHITECTURE.md` - Detailed architecture documentation
- `HEXAGONAL_ARCHITECTURE.md` - Hexagonal architecture guide
- `DDD_GUIDE.md` - Domain-Driven Design principles and patterns
- `BOUNDED_CONTEXTS.md` - Detailed bounded context documentation
- `ONBOARDING.md` - Developer onboarding guide
- `API_GUIDELINES.md` - REST API standards
- `DATABASE_SCHEMA.md` - Database design and migrations
- `EVENT_CATALOG.md` - Domain events documentation
- `DEPLOYMENT.md` - Deployment and infrastructure guide

## 9. Constraints & Assumptions

### 9.1 Constraints
- Must use Kotlin as primary language
- Must support both sync and async flows
- Must maintain backward compatibility during migration
- Budget for infrastructure (development/staging/production)

### 9.2 Assumptions
- Single database instance for all schemas (can shard later)
- PostgreSQL as primary data store
- Redis for caching and sessions
- Event broker to be determined based on scale needs

## 10. Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Over-engineering early | High | Medium | Implement MVP per context first |
| Context boundaries unclear | High | Medium | Regular architecture reviews |
| Performance degradation | Medium | Low | Benchmarking, caching strategy |
| Team learning curve | Medium | Medium | Comprehensive documentation |
| Event consistency issues | High | Low | Proper event sourcing, idempotency |

## 11. Glossary

- **Aggregate**: Cluster of domain objects treated as a single unit
- **Bounded Context**: Explicit boundary within which a domain model is defined
- **Domain Event**: Something that happened in the domain that domain experts care about
- **Port**: Interface that defines how the outside world communicates with the application
- **Adapter**: Implementation of a port
- **Use Case**: Application-specific business rule
- **Value Object**: Immutable object defined by its attributes
- **Entity**: Object defined by its identity, not its attributes

---

**Version**: 1.0
**Last Updated**: 2025-11-29
**Status**: Draft → Review → Approved
