# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ShopNow** is a modern e-commerce platform built with **Hexagonal Architecture** (Ports & Adapters) and **Domain-Driven Design (DDD)** principles. The system is reactive and event-driven, organized into 10 independent bounded contexts.

**Tech Stack:**
- Kotlin 2.1.0 with Java 21
- Spring Boot 3.4.0 with WebFlux (reactive)
- Spring Data R2DBC for reactive database access
- PostgreSQL 17 with schema-per-bounded-context
- Redis 7 for caching
- Flyway for database migrations
- Kotest + MockK for testing

## Essential Commands

### Development Workflow

```bash
# Start infrastructure (PostgreSQL + Redis)
docker-compose up -d

# Start with dev tools (pgAdmin + Redis Insight)
docker-compose --profile dev up -d

# Run database migrations
./gradlew flywayMigrate

# Check migration status
./gradlew flywayInfo

# Run application
./gradlew bootRun

# Run tests
./gradlew test

# Run specific test
./gradlew test --tests "ClassName"

# Build application
./gradlew build

# Clean build
./gradlew clean build
```

**Note:** On Windows, use `gradlew.bat` instead of `./gradlew`

### Application Endpoints

- Health check: http://localhost:8080/actuator/health
- Swagger UI: http://localhost:8080/swagger-ui.html
- API base path: http://localhost:8080/api

### Database Access

- **pgAdmin:** http://localhost:5050 (default: admin@shopnow.local / admin)
- **Redis Insight:** http://localhost:5540

## Architecture Guidelines

### Hexagonal Architecture Structure

The codebase follows strict hexagonal architecture with clear separation:

```
com.shopnow.<context>/
├── domain/              # Core business logic (no framework dependencies)
│   ├── model/          # Aggregates, Entities, Value Objects
│   └── repository/     # Repository interfaces (ports)
├── application/         # Use cases and orchestration
│   ├── usecase/        # Application services
│   ├── command/        # Command objects
│   └── dto/           # Data Transfer Objects
└── infrastructure/      # Framework and external concerns
    ├── web/           # REST controllers (input adapters)
    └── persistence/   # Repository implementations (output adapters)
```

### Bounded Contexts

The system has 10 bounded contexts, each with its own PostgreSQL schema:

1. **catalog** - Product catalog, categories, inventory
2. **identity** - User management, authentication, authorization
3. **shopping** - Shopping cart, wishlist, reviews
4. **orders** - Order management, order lifecycle
5. **payment** - Payment processing, transactions
6. **shipping** - Shipping methods, tracking, delivery
7. **promotion** - Discounts, coupons, promotional campaigns
8. **partner** - Affiliates, suppliers
9. **notification** - User notifications, alerts
10. **audit** - Audit logging, activity tracking

Additionally, there's an **events** schema for event sourcing/event store.

### Domain-Driven Design Patterns

**Aggregate Roots:**
- Extend `AggregateRoot<UUID>` from `com.shopnow.shared.kernel.domain`
- Use private constructors with factory methods (e.g., `Product.create()`)
- Expose behavior through intention-revealing methods, not setters
- Register domain events via `registerEvent(event)`
- Example: `Product`, `User`

**Value Objects:**
- Immutable objects defined by their attributes
- Self-validating in constructors
- Located in `shared.kernel.domain.valueobject` or context-specific packages
- Examples: `Money`, `Email`, `Address`, `Password`

**Domain Events:**
- Extend `BaseDomainEvent(aggregateId, eventType)`
- Named in past tense (e.g., `ProductCreatedEvent`, `UserRegisteredEvent`)
- Automatically include `eventId`, `occurredAt`, `aggregateId`, `eventType`

**Repository Pattern:**
- Interfaces in `domain/repository` (ports)
- Implementations in `infrastructure/persistence` (adapters)
- Use R2DBC's `DatabaseClient` for reactive queries
- Return `Flow<T>` for collections, `suspend fun` for single items

### Reactive Programming

This is a **fully reactive** application using Spring WebFlux and R2DBC:

- Use `suspend fun` for coroutine-based reactive operations
- Return `Flow<T>` for streaming collections
- Never use blocking JDBC operations in reactive code paths
- JDBC is only used for Flyway migrations (synchronous)

**Controller Example:**
```kotlin
@RestController
@RequestMapping("/api/products")
class ProductController(private val useCase: GetAllProductsUseCase) {

    @GetMapping
    suspend fun getAllProducts(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): Flow<ProductDTO> {
        return useCase.execute(page, size)
    }
}
```

### Database Migrations

Migrations are in `src/main/resources/db/migration/`:
- Follow naming: `V{number}__{context}__{description}.sql`
- Schema creation: `V1__create_all_schemas.sql`
- Context-specific: `V2__catalog__create_tables.sql`, `V3__identity__create_tables.sql`
- Always prefix tables with schema: `catalog.products`, `identity.users`

### Key Implementation Patterns

**Creating Aggregates:**
```kotlin
// Use factory methods, not constructors
val product = Product.create(
    sku = "SKU-001",
    name = "Product Name",
    description = "Description",
    price = Money.of(99.99, "USD"),
    initialStock = 100,
    categoryId = categoryId,
    slug = "product-name"
)
```

**Repository Persistence:**
```kotlin
// Repositories use reflection to reconstruct aggregates from database
// This preserves private constructors in domain layer
private fun mapToProduct(row: Map<String, Any>): Product {
    val constructor = Product::class.java.getDeclaredConstructor(...)
    constructor.isAccessible = true
    return constructor.newInstance(...)
}
```

**Use Cases:**
```kotlin
@Service
class CreateProductUseCase(
    private val productRepository: ProductRepository
) {
    suspend fun execute(command: CreateProductCommand): UUID {
        // 1. Create aggregate using factory method
        val product = Product.create(...)

        // 2. Save aggregate
        productRepository.save(product)

        // 3. Return result
        return product.id
    }
}
```

## Important Constraints

1. **Domain Layer Purity**: The `domain` package must never depend on Spring, R2DBC, or any infrastructure framework
2. **No Anemic Models**: Aggregates should contain business logic, not just getters/setters
3. **Immutability**: Value Objects must be immutable (use Kotlin `data class` or Java records)
4. **Event-Driven**: State changes in aggregates must generate domain events
5. **Schema Isolation**: Each bounded context has its own PostgreSQL schema - never cross-reference tables across contexts
6. **Reactive Consistency**: Never mix blocking I/O with reactive code

## Configuration

Application configuration in `src/main/resources/application.yml`:
- Database connection via environment variables: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`
- Redis connection: `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`
- CORS origins: `CORS_ALLOWED_ORIGINS`
- JWT settings: `JWT_SECRET`, `JWT_EXPIRATION`
- Cache TTL configured per entity type

Default values allow running locally without `.env` file:
- PostgreSQL: localhost:5432/shopnow (user: shopnow, password: shopnow)
- Redis: localhost:6379 (no password)

## Testing Guidelines

Test framework: Kotest for Kotlin-idiomatic testing, MockK for mocking

**Domain Tests:**
- Test aggregate behavior without infrastructure
- Verify domain events are raised
- Test invariant enforcement

**Use Case Tests:**
- Mock repository ports
- Test business workflows
- Use `runTest` for coroutine testing

**Integration Tests:**
- Use Testcontainers for PostgreSQL and Redis
- Test full request-response cycles
- Verify database state changes

## Common Tasks

**Adding a New Aggregate:**
1. Create domain model in `<context>/domain/model/`
2. Define repository port in `<context>/domain/repository/`
3. Implement R2DBC repository in `<context>/infrastructure/persistence/`
4. Create use cases in `<context>/application/usecase/`
5. Add REST controller in `<context>/infrastructure/web/`
6. Create migration in `src/main/resources/db/migration/`

**Adding a New Bounded Context:**
1. Create schema in `V1__create_all_schemas.sql` (if not exists)
2. Create package structure: `com.shopnow.<context>/domain/application/infrastructure`
3. Create migration: `V{N}__{context}__create_tables.sql`
4. Follow the same structure as existing contexts (catalog, identity)

**Working with Money:**
```kotlin
// Always use Money value object for monetary amounts
val price = Money.of(BigDecimal("99.99"), "USD")
val total = price.add(tax).multiply(quantity)

// Money validates currency matching and positive amounts
// Operations return new instances (immutable)
```

**Working with Domain Events:**
```kotlin
// In aggregate
fun confirm() {
    status = OrderStatus.CONFIRMED
    registerEvent(OrderConfirmedEvent(id, customerId, calculateTotal()))
}

// After saving aggregate
val events = aggregate.pullDomainEvents()
// Publish events to event bus / store in events schema
```
