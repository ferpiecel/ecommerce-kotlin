# CLAUDE.md - ShopNow E-Commerce Backend Architecture

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ShopNow** is a production-grade e-commerce backend built as a **modular monolith** using **Hexagonal Architecture** (Ports & Adapters) and **Domain-Driven Design (DDD)** principles. The system is fully reactive and event-driven, organized into 10 independent bounded contexts with their own database schemas. It's designed to evolve into microservices when needed.

**Tech Stack:**
- Kotlin 2.1.0 with Java 21
- Spring Boot 3.4.0 with WebFlux (reactive)
- Spring Data R2DBC for reactive database access
- PostgreSQL 17 with schema-per-bounded-context
- Redis 7 for caching
- Flyway for database migrations
- Kotest + MockK for testing

## System Architecture Big Picture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       CLIENT APPLICATIONS                                │
│              (Web Frontend, Mobile Apps, Admin Panel)                    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ HTTP/REST (Reactive - WebFlux)
┌───────────────────────────────▼─────────────────────────────────────────┐
│                      API GATEWAY LAYER                                   │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │  Spring Boot 3.4.0 + WebFlux (Port 8080)                     │     │
│   │  - GlobalExceptionHandler (centralized error handling)       │     │
│   │  - OpenAPI/Swagger Documentation                             │     │
│   │  - CORS Configuration                                        │     │
│   │  - Security (JWT - planned)                                  │     │
│   └──────────────────────────────────────────────────────────────┘     │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐   ┌─────────▼────────┐   ┌─────────▼────────┐
│   CATALOG      │   │   IDENTITY       │   │  SHOPPING        │
│   CONTEXT      │   │   CONTEXT        │   │  CONTEXT         │
│  ✅ Implemented │   │  ✅ Implemented   │   │  🟡 Schema Only  │
│                │   │                  │   │                  │
│ Products       │   │ Users            │   │ Shopping Carts   │
│ Categories     │   │ Roles            │   │ Wishlists        │
│ Inventory      │   │ Permissions      │   │ Reviews          │
└────────────────┘   └──────────────────┘   └──────────────────┘

        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐   ┌─────────▼────────┐   ┌─────────▼────────┐
│   ORDERS       │   │   PAYMENT        │   │  SHIPPING        │
│   CONTEXT      │   │   CONTEXT        │   │  CONTEXT         │
│  🟡 Schema Only │   │  🟡 Schema Only  │   │  🟡 Schema Only  │
└────────────────┘   └──────────────────┘   └──────────────────┘

        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────▼────────┐   ┌─────────▼────────┐   ┌─────────▼────────┐
│  PROMOTION     │   │   PARTNER        │   │ NOTIFICATION     │
│  CONTEXT       │   │   CONTEXT        │   │  CONTEXT         │
│  🟡 Schema Only │   │  🟡 Schema Only  │   │  🟡 Schema Only  │
└────────────────┘   └──────────────────┘   └──────────────────┘

                    ┌─────────▼────────┐
                    │   AUDIT          │
                    │   CONTEXT        │
                    │  🟡 Schema Only  │
                    └─────────┬────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────▼────────┐   ┌────────▼───────┐   ┌────────▼───────┐
│  PostgreSQL 17 │   │   Redis 7      │   │  Event Store   │
│  (11 schemas)  │   │   (Caching)    │   │  (events       │
│                │   │                │   │   schema)      │
└────────────────┘   └────────────────┘   └────────────────┘
```

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

- **Health check:** http://localhost:8080/actuator/health
- **Swagger UI:** http://localhost:8080/swagger-ui.html
- **API base path:** http://localhost:8080/api
- **Metrics:** http://localhost:8080/actuator/metrics
- **Prometheus:** http://localhost:8080/actuator/prometheus

### Database Access

- **pgAdmin:** http://localhost:5050 (admin@shopnow.local / admin)
- **Redis Insight:** http://localhost:5540

## Architecture Patterns in Detail

### 1. Hexagonal Architecture (Ports & Adapters)

Each bounded context follows strict hexagonal architecture with clear separation of concerns:

```
┌────────────────────────────────────────────────────────────────┐
│                   BOUNDED CONTEXT                              │
│                                                                │
│  ┌──────────────────────────────────────────────────────┐    │
│  │           DOMAIN LAYER (Pure Business Logic)         │    │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │    │
│  │  NO FRAMEWORK DEPENDENCIES!                          │    │
│  │  - Aggregates (Product, User, Order)                 │    │
│  │  - Value Objects (Money, Email, Address)             │    │
│  │  - Domain Events (ProductCreated, UserRegistered)    │    │
│  │  - Repository Ports (interfaces)                     │    │
│  │  - Domain Exceptions (BusinessRuleViolation)         │    │
│  └──────────────────┬───────────────────────────────────┘    │
│                     │                                         │
│  ┌──────────────────▼───────────────────────────────────┐    │
│  │        APPLICATION LAYER (Use Case Orchestration)    │    │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │    │
│  │  - Commands (CreateProductCommand)                   │    │
│  │  - DTOs (ProductDTO - for API responses)             │    │
│  │  - Use Cases (CreateProductUseCase)                  │    │
│  │  - Orchestrates domain objects                       │    │
│  │  - Transaction boundaries                            │    │
│  └──────────┬──────────────────────────────────┬────────┘    │
│             │                                  │             │
│  ┌──────────▼──────────────┐    ┌─────────────▼─────────┐   │
│  │   INFRASTRUCTURE         │    │   INFRASTRUCTURE      │   │
│  │   INPUT ADAPTERS         │    │   OUTPUT ADAPTERS     │   │
│  │   (Web Layer)            │    │   (Persistence)       │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━  │    │  ━━━━━━━━━━━━━━━━━━━ │   │
│  │  - REST Controllers      │    │  - R2DBC Repositories │   │
│  │  - Request validation    │    │  - DatabaseClient     │   │
│  │  - Response mapping      │    │  - Row mapping        │   │
│  │  - Exception handling    │    │  - SQL queries        │   │
│  └──────────────────────────┘    └───────────────────────┘   │
└────────────────────────────────────────────────────────────────┘
```

**Directory Structure per Context:**

```
com.shopnow.<context>/
├── domain/                    # PURE BUSINESS LOGIC
│   ├── model/                # Aggregates, Entities, Value Objects
│   │   ├── Product.kt        # Aggregate root with behavior
│   │   ├── ProductStatus.kt  # Enums
│   │   └── events/           # Domain events
│   └── repository/           # Repository port (interface)
│       └── ProductRepository.kt
│
├── application/              # USE CASE ORCHESTRATION
│   ├── command/
│   │   └── CreateProductCommand.kt
│   ├── dto/
│   │   └── ProductDTO.kt
│   └── usecase/
│       ├── CreateProductUseCase.kt
│       ├── GetAllProductsUseCase.kt
│       └── GetProductByIdUseCase.kt
│
└── infrastructure/           # FRAMEWORK & EXTERNAL CONCERNS
    ├── persistence/         # Output adapter
    │   └── R2dbcProductRepository.kt
    └── web/                 # Input adapter
        └── ProductController.kt
```

**Key Principles:**
- **Domain layer** has ZERO dependencies on Spring, R2DBC, or any framework
- **Ports** (interfaces) are defined in the domain layer
- **Adapters** implement ports in infrastructure layer
- **Dependency Rule**: Dependencies point inward (Infrastructure → Application → Domain)

### 2. Domain-Driven Design (DDD)

#### Bounded Contexts Implementation Status

| Context      | Status       | Aggregates                  | Schema Tables | Code Files |
|--------------|--------------|-----------------------------|--------------:|----------:|
| **catalog**  | ✅ Implemented | Product, Category          | 4            | 9         |
| **identity** | ✅ Implemented | User, Role, Permission     | 7            | 10        |
| **shopping** | 🟡 Schema Only | ShoppingCart, Wishlist, Review | 5         | 0         |
| **orders**   | 🟡 Schema Only | Order                      | 4            | 0         |
| **payment**  | 🟡 Schema Only | Payment, PaymentMethod     | 3            | 0         |
| **shipping** | 🟡 Schema Only | Shipment                   | 3            | 0         |
| **promotion**| 🟡 Schema Only | Promotion, Coupon          | 3            | 0         |
| **partner**  | 🟡 Schema Only | Partner, Affiliate         | 3            | 0         |
| **notification** | 🟡 Schema Only | Notification           | 3            | 0         |
| **audit**    | 🟡 Schema Only | AuditLog                   | 2            | 0         |

✅ = Fully implemented (domain, application, infrastructure)
🟡 = Database schema created, awaiting code implementation

#### DDD Building Blocks

**1. Aggregate Roots:**

Aggregates are the core of DDD - they are consistency boundaries that encapsulate business logic and protect invariants.

```kotlin
// Example: Product Aggregate Root
class Product private constructor(
    id: UUID,
    val sku: String,
    private var name: String,
    private var description: String,
    private var price: Money,
    private var stock: Int,
    private var status: ProductStatus,
    val categoryId: UUID,
    val slug: String,
    private var featured: Boolean = false
) : AggregateRoot<UUID>(id) {

    companion object {
        // Factory method - domain-driven creation
        fun create(
            sku: String,
            name: String,
            description: String,
            price: Money,
            initialStock: Int,
            categoryId: UUID,
            slug: String
        ): Product {
            val product = Product(
                id = UUID.randomUUID(),
                sku = sku,
                name = name,
                description = description,
                price = price,
                stock = initialStock,
                status = ProductStatus.DRAFT,
                categoryId = categoryId,
                slug = slug
            )
            // Register domain event
            product.registerEvent(ProductCreatedEvent(product.id, sku, name, price))
            return product
        }
    }

    // Behavior-rich domain methods (NOT just getters/setters!)
    fun changePrice(newPrice: Money) {
        require(status != ProductStatus.DELETED) { "Cannot change price of deleted product" }
        val oldPrice = price
        price = newPrice
        registerEvent(ProductPriceChangedEvent(id, oldPrice, newPrice))
    }

    fun reserveStock(quantity: Int) {
        require(quantity > 0) { "Quantity must be positive" }
        require(stock >= quantity) { "Insufficient stock" }
        stock -= quantity
        registerEvent(StockReservedEvent(id, quantity))
    }

    fun releaseStock(quantity: Int) {
        stock += quantity
        registerEvent(StockReleasedEvent(id, quantity))
    }

    fun activate() {
        require(status == ProductStatus.DRAFT) { "Can only activate draft products" }
        status = ProductStatus.ACTIVE
        registerEvent(ProductActivatedEvent(id))
    }

    fun deactivate() {
        status = ProductStatus.INACTIVE
        registerEvent(ProductDeactivatedEvent(id))
    }

    // Getters for read-only access
    fun getName() = name
    fun getPrice() = price
    fun getStock() = stock
    fun getStatus() = status
}
```

**Key Points:**
- Private constructor prevents invalid creation
- Factory method (`create()`) ensures valid initialization
- All state changes go through behavior methods
- Domain events are registered automatically
- No setters - only intention-revealing methods

**2. Value Objects:**

Value objects are immutable objects defined by their attributes, not identity.

**Shared Kernel Value Objects** (`com.shopnow.shared.kernel.domain.valueobject`):

```kotlin
// Money - Currency-aware monetary amounts
data class Money(
    val amount: BigDecimal,
    val currency: String
) : ValueObject {
    init {
        require(amount >= BigDecimal.ZERO) { "Amount must be non-negative" }
        require(currency.length == 3) { "Currency must be ISO 4217 code (3 chars)" }
    }

    companion object {
        fun of(amount: BigDecimal, currency: String) = Money(amount, currency)
        fun of(amount: Double, currency: String) = Money(BigDecimal.valueOf(amount), currency)
    }

    // Operations return new instances (immutable)
    fun add(other: Money): Money {
        require(currency == other.currency) { "Cannot add different currencies" }
        return Money(amount + other.amount, currency)
    }

    fun multiply(multiplier: Int): Money = Money(amount * multiplier.toBigDecimal(), currency)

    fun isZero() = amount == BigDecimal.ZERO
}

// Email - Self-validating email addresses
data class Email(val value: String) : ValueObject {
    init {
        require(isValid(value)) { "Invalid email format: $value" }
    }

    companion object {
        private val EMAIL_REGEX = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$".toRegex()

        private fun isValid(email: String): Boolean = EMAIL_REGEX.matches(email)
    }
}

// Address - Complete address with country code
data class Address(
    val street: String,
    val city: String,
    val state: String,
    val zipCode: String,
    val country: CountryCode
) : ValueObject

// CountryCode - ISO 3166-1 alpha-2
data class CountryCode(val code: String) : ValueObject {
    init {
        require(code.length == 2) { "Country code must be 2 characters (ISO 3166-1 alpha-2)" }
        require(code.all { it.isUpperCase() }) { "Country code must be uppercase" }
    }
}
```

**Context-Specific Value Objects** (`com.shopnow.identity.domain.model`):

```kotlin
// Password - BCrypt hashed passwords
data class Password private constructor(val hashedValue: String) {
    companion object {
        private val bcryptEncoder = BCryptPasswordEncoder()

        fun fromPlainText(plainText: String): Password {
            require(plainText.length >= 8) { "Password must be at least 8 characters" }
            return Password(bcryptEncoder.encode(plainText))
        }

        fun fromHash(hash: String): Password = Password(hash)
    }

    fun matches(plainText: String): Boolean = bcryptEncoder.matches(plainText, hashedValue)
}
```

**3. Domain Events:**

Domain events capture important business occurrences and enable event-driven architecture.

```kotlin
// Base class in shared kernel
abstract class BaseDomainEvent(
    val aggregateId: UUID,
    val eventType: String,
    val eventId: UUID = UUID.randomUUID(),
    val occurredAt: Instant = Instant.now()
)

// Example: Catalog context events
data class ProductCreatedEvent(
    val productId: UUID,
    val sku: String,
    val name: String,
    val price: Money
) : BaseDomainEvent(productId, "ProductCreated")

data class ProductPriceChangedEvent(
    val productId: UUID,
    val oldPrice: Money,
    val newPrice: Money
) : BaseDomainEvent(productId, "ProductPriceChanged")

data class StockReservedEvent(
    val productId: UUID,
    val quantity: Int,
    val reservationId: UUID = UUID.randomUUID()
) : BaseDomainEvent(productId, "StockReserved")

// Example: Identity context events
data class UserRegisteredEvent(
    val userId: UUID,
    val email: String,
    val fullName: String
) : BaseDomainEvent(userId, "UserRegistered")

data class UserActivatedEvent(
    val userId: UUID,
    val activatedAt: Instant
) : BaseDomainEvent(userId, "UserActivated")

data class PasswordChangedEvent(
    val userId: UUID
) : BaseDomainEvent(userId, "PasswordChanged")
```

**Events are automatically managed by AggregateRoot:**

```kotlin
abstract class AggregateRoot<ID>(val id: ID) {
    private val domainEvents = mutableListOf<BaseDomainEvent>()

    protected fun registerEvent(event: BaseDomainEvent) {
        domainEvents.add(event)
    }

    fun pullDomainEvents(): List<BaseDomainEvent> {
        val events = domainEvents.toList()
        domainEvents.clear()
        return events
    }

    fun clearDomainEvents() {
        domainEvents.clear()
    }
}
```

**4. Repository Pattern:**

Repositories provide collection-like access to aggregates while hiding persistence details.

```kotlin
// PORT (interface in domain layer)
interface ProductRepository {
    suspend fun save(product: Product): Product
    suspend fun findById(id: UUID): Product?
    suspend fun findAll(page: Int, size: Int): Flow<Product>
    suspend fun findBySku(sku: String): Product?
    suspend fun existsBySku(sku: String): Boolean
    suspend fun delete(id: UUID)
}

// ADAPTER (implementation in infrastructure layer)
@Repository
class R2dbcProductRepository(
    private val databaseClient: DatabaseClient
) : ProductRepository {

    override suspend fun save(product: Product): Product {
        val sql = """
            INSERT INTO catalog.products (id, sku, name, description, price_amount,
                                          price_currency, stock, status, category_id,
                                          slug, featured, created_at, updated_at)
            VALUES (:id, :sku, :name, :description, :price_amount, :price_currency,
                    :stock, :status, :category_id, :slug, :featured, NOW(), NOW())
            ON CONFLICT (id) DO UPDATE SET
                name = EXCLUDED.name,
                description = EXCLUDED.description,
                price_amount = EXCLUDED.price_amount,
                price_currency = EXCLUDED.price_currency,
                stock = EXCLUDED.stock,
                status = EXCLUDED.status,
                featured = EXCLUDED.featured,
                updated_at = NOW()
        """.trimIndent()

        databaseClient.sql(sql)
            .bind("id", product.id)
            .bind("sku", product.sku)
            .bind("name", product.getName())
            // ... other bindings
            .await()

        return product
    }

    override suspend fun findById(id: UUID): Product? {
        return databaseClient.sql("SELECT * FROM catalog.products WHERE id = :id")
            .bind("id", id)
            .map { row, _ -> mapToProduct(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findAll(page: Int, size: Int): Flow<Product> {
        return databaseClient.sql("""
            SELECT * FROM catalog.products
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
            .bind("limit", size)
            .bind("offset", page * size)
            .map { row, _ -> mapToProduct(row) }
            .flow()
    }

    // Uses reflection to preserve private constructor in domain layer
    private fun mapToProduct(row: Row): Product {
        val constructor = Product::class.java.getDeclaredConstructor(
            UUID::class.java, String::class.java, String::class.java,
            String::class.java, Money::class.java, Int::class.javaPrimitiveType,
            ProductStatus::class.java, UUID::class.java, String::class.java,
            Boolean::class.javaPrimitiveType
        )
        constructor.isAccessible = true

        return constructor.newInstance(
            row.get("id", UUID::class.java),
            row.get("sku", String::class.java),
            row.get("name", String::class.java),
            row.get("description", String::class.java),
            Money(
                row.get("price_amount", BigDecimal::class.java)!!,
                row.get("price_currency", String::class.java)!!
            ),
            row.get("stock", Integer::class.java)?.toInt(),
            ProductStatus.valueOf(row.get("status", String::class.java)!!),
            row.get("category_id", UUID::class.java),
            row.get("slug", String::class.java)!!,
            row.get("featured", java.lang.Boolean::class.java)?.booleanValue() ?: false
        )
    }
}
```

**5. Use Case Pattern:**

Use cases orchestrate domain objects to fulfill application requirements.

```kotlin
@Service
class CreateProductUseCase(
    private val productRepository: ProductRepository
) {
    suspend fun execute(command: CreateProductCommand): UUID {
        // 1. Validate business rules
        if (productRepository.existsBySku(command.sku)) {
            throw BusinessRuleViolationException("Product with SKU ${command.sku} already exists")
        }

        // 2. Create aggregate using factory method
        val product = Product.create(
            sku = command.sku,
            name = command.name,
            description = command.description,
            price = Money.of(command.price, command.currency),
            initialStock = command.initialStock,
            categoryId = command.categoryId,
            slug = command.slug
        )

        // 3. Save aggregate (events are registered inside aggregate)
        productRepository.save(product)

        // 4. Pull and publish domain events (if event publisher is available)
        // val events = product.pullDomainEvents()
        // eventPublisher.publishAll(events)

        // 5. Return result
        return product.id
    }
}
```

### 3. Event-Driven Architecture

The system is built for event-driven communication between bounded contexts.

#### Event Store Schema

```sql
-- events.domain_events - Stores all domain events from all contexts
CREATE TABLE events.domain_events (
    event_id UUID PRIMARY KEY,
    event_type VARCHAR(255) NOT NULL,
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(255) NOT NULL,
    event_data JSONB NOT NULL,
    occurred_at TIMESTAMP NOT NULL,
    sequence_number BIGSERIAL NOT NULL,
    correlation_id UUID,
    causation_id UUID,
    metadata JSONB
);

-- events.event_subscriptions - Tracks which contexts processed which events
CREATE TABLE events.event_subscriptions (
    subscription_id UUID PRIMARY KEY,
    subscriber_name VARCHAR(255) NOT NULL UNIQUE,
    last_processed_sequence BIGINT NOT NULL DEFAULT 0,
    last_processed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- events.event_processing_log - Ensures idempotent event processing
CREATE TABLE events.event_processing_log (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL,
    subscriber_name VARCHAR(255) NOT NULL,
    processed_at TIMESTAMP NOT NULL,
    status VARCHAR(50) NOT NULL,
    error_message TEXT,
    UNIQUE(event_id, subscriber_name)
);

-- events.aggregate_snapshots - Event sourcing optimization
CREATE TABLE events.aggregate_snapshots (
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(255) NOT NULL,
    sequence_number BIGINT NOT NULL,
    snapshot_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (aggregate_id, sequence_number)
);
```

#### Event Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  EVENT FLOW ARCHITECTURE                    │
└─────────────────────────────────────────────────────────────┘

1. DOMAIN EVENT GENERATION
   ┌──────────────┐
   │  Aggregate   │  State change → registerEvent(event)
   │  (Product)   │
   └──────┬───────┘
          │
          ▼
   ┌──────────────┐
   │  Use Case    │  Save aggregate → pullDomainEvents()
   └──────┬───────┘
          │
          ▼

2. EVENT PERSISTENCE
   ┌──────────────────────────────────────────────┐
   │  Event Store (events.domain_events)         │
   │  - eventId, eventType, aggregateId          │
   │  - eventData (JSONB with full payload)      │
   │  - sequenceNumber (for ordering)            │
   │  - correlationId (trace related events)     │
   └──────────────────────────────────────────────┘
          │
          ▼

3. EVENT SUBSCRIPTION & PROCESSING
   ┌──────────────────────────────────────────────┐
   │  event_subscriptions                         │
   │  - Tracks last processed sequence per        │
   │    subscriber (context)                      │
   └──────────────────────────────────────────────┘
          │
          ▼
   ┌──────────────────────────────────────────────┐
   │  event_processing_log                        │
   │  - Ensures idempotent processing             │
   │  - Prevents duplicate event handling         │
   └──────────────────────────────────────────────┘
          │
          ▼

4. CROSS-CONTEXT COMMUNICATION
   Catalog Context             Orders Context
   ┌──────────────┐           ┌──────────────┐
   │ ProductCreated│──────────▶│ Subscribe to │
   │ Event         │           │ catalog events│
   │               │           │ Update cache │
   └───────────────┘           └──────────────┘
```

**Helper Functions for Event Processing:**

```sql
-- Get new events for a subscriber
CREATE FUNCTION events.get_new_events_for_subscriber(
    p_subscriber_name VARCHAR,
    p_limit INT DEFAULT 100
) RETURNS TABLE(...) AS $$
    SELECT e.* FROM events.domain_events e
    INNER JOIN events.event_subscriptions s
        ON s.subscriber_name = p_subscriber_name
    WHERE e.sequence_number > s.last_processed_sequence
    ORDER BY e.sequence_number
    LIMIT p_limit;
$$;

-- Mark event as processed
CREATE PROCEDURE events.mark_event_processed(
    p_event_id UUID,
    p_subscriber_name VARCHAR,
    p_sequence_number BIGINT
) AS $$
    -- Update subscription
    UPDATE events.event_subscriptions
    SET last_processed_sequence = p_sequence_number,
        last_processed_at = NOW()
    WHERE subscriber_name = p_subscriber_name;

    -- Log processing
    INSERT INTO events.event_processing_log (...)
    VALUES (...);
$$;
```

### 4. Reactive Programming (End-to-End Non-Blocking)

The entire application is **fully reactive** using Spring WebFlux and R2DBC - no blocking I/O anywhere in the request path.

```
┌────────────────────────────────────────────────────────────┐
│           REACTIVE STACK (Non-Blocking I/O)                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  HTTP Request                                              │
│       │                                                    │
│       ▼                                                    │
│  ┌────────────────────────────────────┐                  │
│  │  Spring WebFlux (Reactor Netty)    │                  │
│  │  - Event loop based                │                  │
│  │  - Non-blocking HTTP               │                  │
│  └────────┬───────────────────────────┘                  │
│           │                                                │
│           ▼                                                │
│  ┌────────────────────────────────────┐                  │
│  │  Controller (suspend fun)          │                  │
│  │  - Coroutine-based async           │                  │
│  │  - Returns Flow<T> or suspend      │                  │
│  └────────┬───────────────────────────┘                  │
│           │                                                │
│           ▼                                                │
│  ┌────────────────────────────────────┐                  │
│  │  Use Case (suspend fun)            │                  │
│  │  - Async business logic            │                  │
│  └────────┬───────────────────────────┘                  │
│           │                                                │
│           ▼                                                │
│  ┌────────────────────────────────────┐                  │
│  │  R2DBC Repository                  │                  │
│  │  - Reactive database driver         │                  │
│  │  - DatabaseClient                  │                  │
│  │  - awaitFirstOrNull(), flow()      │                  │
│  └────────┬───────────────────────────┘                  │
│           │                                                │
│           ▼                                                │
│  ┌────────────────────────────────────┐                  │
│  │  PostgreSQL (R2DBC protocol)       │                  │
│  │  - Non-blocking I/O                │                  │
│  │  - Connection pooling              │                  │
│  └────────────────────────────────────┘                  │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

**Reactive Patterns in Code:**

```kotlin
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CONTROLLER - Input Adapter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@RestController
@RequestMapping("/api/products")
class ProductController(
    private val getAllProductsUseCase: GetAllProductsUseCase,
    private val getProductByIdUseCase: GetProductByIdUseCase,
    private val createProductUseCase: CreateProductUseCase
) {

    // Returns Flow<T> for streaming collections
    @GetMapping
    suspend fun getAllProducts(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): Flow<ProductDTO> {
        return getAllProductsUseCase.execute(page, size)
    }

    // Returns single value with suspend
    @GetMapping("/{id}")
    suspend fun getProductById(@PathVariable id: UUID): ResponseEntity<ProductDTO> {
        val product = getProductByIdUseCase.execute(id)
            ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok(product)
    }

    // Accepts request body and returns suspend
    @PostMapping
    suspend fun createProduct(@RequestBody command: CreateProductCommand): ResponseEntity<UUID> {
        val productId = createProductUseCase.execute(command)
        return ResponseEntity.created(URI.create("/api/products/$productId"))
            .body(productId)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// USE CASE - Application Layer
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@Service
class GetAllProductsUseCase(
    private val productRepository: ProductRepository
) {
    suspend fun execute(page: Int, size: Int): Flow<ProductDTO> {
        return productRepository.findAll(page, size)
            .map { it.toDTO() }  // Transform domain to DTO
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// REPOSITORY - Output Adapter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
@Repository
class R2dbcProductRepository(
    private val databaseClient: DatabaseClient
) : ProductRepository {

    // Returns Flow<T> for reactive streaming
    override suspend fun findAll(page: Int, size: Int): Flow<Product> {
        return databaseClient.sql("""
            SELECT * FROM catalog.products
            WHERE status != 'DELETED'
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)
            .bind("limit", size)
            .bind("offset", page * size)
            .map { row, _ -> mapToProduct(row) }
            .flow()  // Convert to Kotlin Flow
    }

    // Returns nullable with suspend (single value)
    override suspend fun findById(id: UUID): Product? {
        return databaseClient.sql("SELECT * FROM catalog.products WHERE id = :id")
            .bind("id", id)
            .map { row, _ -> mapToProduct(row) }
            .awaitFirstOrNull()  // Suspend until result or null
    }

    // Saves and returns aggregate
    override suspend fun save(product: Product): Product {
        databaseClient.sql("""
            INSERT INTO catalog.products (...)
            VALUES (...)
            ON CONFLICT (id) DO UPDATE SET ...
        """)
            // ... bindings
            .await()  // Suspend until complete

        return product
    }
}
```

**Key Reactive Principles:**

1. **Never block**: No `Thread.sleep()`, no blocking JDBC, no synchronous I/O
2. **Use `suspend fun`**: For single async values
3. **Use `Flow<T>`**: For streaming/multiple values
4. **R2DBC everywhere**: DatabaseClient for all database operations
5. **Connection pooling**: R2DBC pool configured in application.yml

**⚠️ CRITICAL RULE:**
- JDBC is **ONLY** used for Flyway migrations (synchronous, startup-time)
- R2DBC is used for **ALL** runtime database operations
- Never mix blocking and non-blocking code in reactive paths

## Database Architecture

### Schema-per-Context Pattern

Each bounded context has its own PostgreSQL schema - **complete isolation**:

```
PostgreSQL Instance (shopnow database)
├── catalog schema
│   ├── products (UUID pk, sku, name, price, stock, status, featured)
│   ├── categories (UUID pk, name, description, parent_id, tree structure)
│   ├── product_images (UUID pk, product_id, image_url, display_order)
│   └── inventory_movements (UUID pk, product_id, movement_type, quantity, reason)
│
├── identity schema
│   ├── users (UUID pk, email, password_hash, status, failed_login_attempts)
│   ├── roles (UUID pk, name, description, permissions JSONB)
│   ├── permissions (UUID pk, resource, action)
│   ├── user_roles (user_id, role_id)
│   ├── refresh_tokens (token, user_id, expires_at)
│   ├── password_reset_tokens (token, user_id, expires_at)
│   └── email_verification_tokens (token, user_id, expires_at)
│
├── shopping schema
│   ├── shopping_carts (UUID pk, user_id, status, expires_at)
│   ├── cart_items (UUID pk, cart_id, product_id, quantity, price_snapshot)
│   ├── wishlists (UUID pk, user_id, name, visibility)
│   ├── wishlist_items (UUID pk, wishlist_id, product_id, priority)
│   └── product_reviews (UUID pk, product_id, user_id, rating, comment, verified_purchase)
│
├── orders schema
│   ├── orders (UUID pk, user_id, status, total_amount, shipping_address JSONB)
│   ├── order_items (UUID pk, order_id, product_id, quantity, unit_price, subtotal)
│   ├── order_status_history (UUID pk, order_id, old_status, new_status, changed_at)
│   └── order_discounts (UUID pk, order_id, discount_code, discount_amount)
│
├── payment schema
│   ├── payment_methods (UUID pk, user_id, type, provider, details JSONB)
│   ├── payments (UUID pk, order_id, payment_method_id, amount, status, transaction_id)
│   └── refunds (UUID pk, payment_id, amount, reason, status)
│
├── shipping schema
│   ├── shipping_methods (UUID pk, name, carrier, base_price, estimated_days)
│   ├── shipments (UUID pk, order_id, tracking_number, carrier, status, shipped_at)
│   └── tracking_events (UUID pk, shipment_id, status, location, occurred_at, description)
│
├── promotion schema
│   ├── promotions (UUID pk, name, type, discount_type, discount_value, start_date, end_date)
│   ├── coupons (UUID pk, code, promotion_id, max_uses, used_count, expires_at)
│   └── coupon_uses (UUID pk, coupon_id, order_id, user_id, used_at)
│
├── partner schema
│   ├── partners (UUID pk, type, company_name, contact_email, status, commission_rate)
│   ├── partner_products (UUID pk, partner_id, product_id, partner_sku, commission_override)
│   └── commissions (UUID pk, partner_id, order_id, amount, status, paid_at)
│
├── notification schema
│   ├── notification_templates (UUID pk, name, type, subject, body_template, channel)
│   ├── notifications (UUID pk, user_id, template_id, status, data JSONB, scheduled_at)
│   └── notification_history (UUID pk, notification_id, channel, status, sent_at, error)
│
├── audit schema
│   ├── audit_logs (UUID pk, user_id, entity_type, entity_id, action, old_value JSONB, new_value JSONB)
│   └── security_audit_logs (UUID pk, user_id, event_type, ip_address, user_agent, success)
│
└── events schema (SHARED EVENT STORE)
    ├── domain_events (event_id UUID pk, event_type, aggregate_id, event_data JSONB, sequence_number)
    ├── event_subscriptions (subscriber_name, last_processed_sequence, last_processed_at)
    ├── event_processing_log (event_id, subscriber_name, processed_at, status)
    └── aggregate_snapshots (aggregate_id, aggregate_type, sequence_number, snapshot_data JSONB)
```

### Database Features

**Flyway Migrations** (`src/main/resources/db/migration/`):

- `V1__create_all_schemas.sql` - Creates all 11 schemas
- `V2__catalog__create_tables.sql` - Catalog context tables
- `V3__identity__create_tables.sql` - Identity context tables
- `V4__events__create_event_store.sql` - Event store infrastructure
- `V5-V12` - Other context tables

**Naming Convention:**
```
V{number}__{context}__{description}.sql
```

**Common Database Patterns:**

1. **UUID Primary Keys**: `gen_random_uuid()`
2. **Timestamps**: `created_at`, `updated_at` with automatic triggers
3. **JSONB**: For flexible schema evolution (event_data, metadata, etc.)
4. **Full-Text Search**: GIN indexes on catalog.products
5. **Soft Deletes**: `status = 'DELETED'` (not actual DELETE)
6. **Optimistic Locking**: `version` column (for future implementation)

**⚠️ CRITICAL RULES:**

1. **NO cross-schema foreign keys** - contexts are isolated
2. **Reference by ID only** - `product_id UUID` (not FK to catalog.products)
3. **All tables prefixed with schema** - `catalog.products`, `identity.users`
4. **Events for cross-context data** - Don't join across schemas; subscribe to events

## Data Flow Examples

### Example 1: Create Product (End-to-End)

```
1. HTTP POST /api/products
   Body: { "sku": "SKU-001", "name": "Product", "price": 99.99, ... }
   ↓

2. ProductController.createProduct(command)
   - Validates request body
   - Calls use case
   ↓

3. CreateProductUseCase.execute(command)
   - Validates business rules (SKU uniqueness)
   - Calls Product.create() factory method
     → ProductCreatedEvent registered in aggregate
   - Saves aggregate to repository
   - Returns product ID
   ↓

4. R2dbcProductRepository.save(product)
   - INSERT INTO catalog.products (...)
   - Optionally save domain events to events.domain_events
   - Returns saved product
   ↓

5. HTTP 201 Created
   Location: /api/products/{id}
   Body: "{id}"
```

### Example 2: Cross-Context Event Flow (Order → Inventory)

```
ORDERS CONTEXT                    CATALOG CONTEXT
      │                                 │
      │ 1. Create Order                 │
      │    └─ Order.create()            │
      │       └─ StockReservationRequested Event
      ├─────────────────────────────────┤
      │ 2. Save to event store          │
      │    (events.domain_events)       │
      ├─────────────────────────────────┤
      │                                 │
      │    3. Poll for new events ──────▶
      │                                 │
      │                                 │ 4. Process event
      │                                 │    - Load Product
      │                                 │    - product.reserveStock()
      │                                 │    - Save Product
      │                                 │      └─ StockReservedEvent
      │                                 │
      │    5. Mark as processed ◀───────┤
      │    (event_subscriptions)        │
      │                                 │
      │ 6. Listen for StockReservedEvent│
      │    - Update order status        │
      │                                 │
```

## Configuration

### Application Configuration (`application.yml`)

**Database (R2DBC - Reactive):**
```yaml
spring:
  r2dbc:
    url: r2dbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:shopnow}
    username: ${DB_USER:shopnow}
    password: ${DB_PASSWORD:shopnow}
    pool:
      initial-size: 10
      max-size: 20
      max-idle-time: 30m
      validation-query: SELECT 1
```

**Database (JDBC - For Flyway Only):**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:shopnow}
    username: ${DB_USER:shopnow}
    password: ${DB_PASSWORD:shopnow}
```

**Redis (Caching):**
```yaml
spring:
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
      password: ${REDIS_PASSWORD:}
      lettuce:
        pool:
          max-active: 8
          max-idle: 8
          min-idle: 2
      timeout: 60s
```

**Flyway (Migrations):**
```yaml
spring:
  flyway:
    enabled: true
    baseline-on-migrate: true
    validate-on-migrate: true
    schemas:
      - catalog
      - identity
      - shopping
      - orders
      - payment
      - shipping
      - promotion
      - partner
      - notification
      - audit
      - events
```

**Environment Variables:**

Create `.env` file in project root (or use defaults):

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=shopnow
DB_USER=shopnow
DB_PASSWORD=shopnow

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Security (future)
JWT_SECRET=your-secret-key
JWT_EXPIRATION=86400000

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:4200

# Dev Tools
PGADMIN_EMAIL=admin@shopnow.local
PGADMIN_PASSWORD=admin
PGADMIN_PORT=5050
```

## Important Constraints & Rules

### Architectural Constraints

1. **Domain Layer Purity**
   - The `domain` package must NEVER depend on Spring, R2DBC, or any infrastructure framework
   - Only pure Kotlin/Java code in domain layer
   - No `@Service`, `@Repository`, `@Component` annotations in domain

2. **No Anemic Models**
   - Aggregates must contain business logic, not just getters/setters
   - Use intention-revealing methods: `product.reserveStock()`, not `product.setStock()`
   - Private constructors with factory methods

3. **Immutability**
   - Value Objects must be immutable (Kotlin `data class` with `val`)
   - Use `copy()` for modifications
   - All operations return new instances

4. **Event-Driven**
   - All state changes in aggregates must generate domain events
   - Events are named in past tense: `ProductCreated`, not `CreateProduct`
   - Events include full context (no need to query)

5. **Schema Isolation**
   - Each bounded context has its own PostgreSQL schema
   - **NEVER** create foreign keys across schemas
   - Reference other contexts by ID only
   - Use events for cross-context data synchronization

6. **Reactive Consistency**
   - Never mix blocking I/O with reactive code
   - Use `suspend fun` for single values
   - Use `Flow<T>` for collections
   - R2DBC for all runtime database access
   - JDBC only for Flyway migrations

### Coding Standards

**Kotlin Conventions:**
- Use `data class` for DTOs and Value Objects
- Use `sealed class` for hierarchies (e.g., domain events)
- Prefer `val` over `var`
- Use extension functions for mapping: `fun Product.toDTO()`

**Naming Conventions:**
- Aggregates: `Product`, `User`, `Order`
- Value Objects: `Money`, `Email`, `Address`
- Events: `ProductCreatedEvent`, `UserRegisteredEvent`
- Commands: `CreateProductCommand`, `UpdateUserCommand`
- DTOs: `ProductDTO`, `UserDTO`
- Use Cases: `CreateProductUseCase`, `GetAllProductsUseCase`
- Repositories: `ProductRepository`, `UserRepository`

## Testing Guidelines

### Test Framework

- **Kotest** for Kotlin-idiomatic testing
- **MockK** for mocking
- **Testcontainers** for integration tests

### Test Structure

**Domain Tests:**
```kotlin
class ProductTest : StringSpec({
    "should create product with valid data" {
        val product = Product.create(
            sku = "SKU-001",
            name = "Test Product",
            description = "Description",
            price = Money.of(99.99, "USD"),
            initialStock = 100,
            categoryId = UUID.randomUUID(),
            slug = "test-product"
        )

        product.getName() shouldBe "Test Product"
        product.getStock() shouldBe 100
        product.getStatus() shouldBe ProductStatus.DRAFT
    }

    "should register ProductCreatedEvent when created" {
        val product = Product.create(...)
        val events = product.pullDomainEvents()

        events shouldHaveSize 1
        events[0] shouldBeInstanceOf<ProductCreatedEvent>()
    }

    "should reserve stock when available" {
        val product = Product.create(..., initialStock = 100, ...)

        product.reserveStock(10)

        product.getStock() shouldBe 90
        val events = product.pullDomainEvents()
        events.last() shouldBeInstanceOf<StockReservedEvent>()
    }

    "should throw exception when reserving more stock than available" {
        val product = Product.create(..., initialStock = 5, ...)

        shouldThrow<IllegalArgumentException> {
            product.reserveStock(10)
        }
    }
})
```

**Use Case Tests:**
```kotlin
class CreateProductUseCaseTest : StringSpec({
    val productRepository = mockk<ProductRepository>()
    val useCase = CreateProductUseCase(productRepository)

    beforeTest {
        clearMocks(productRepository)
    }

    "should create product when SKU is unique" {
        val command = CreateProductCommand(
            sku = "SKU-001",
            name = "Test",
            price = 99.99,
            currency = "USD",
            // ...
        )

        coEvery { productRepository.existsBySku("SKU-001") } returns false
        coEvery { productRepository.save(any()) } returns mockk()

        val result = useCase.execute(command)

        result shouldNotBe null
        coVerify { productRepository.save(any()) }
    }

    "should throw exception when SKU already exists" {
        val command = CreateProductCommand(sku = "SKU-001", ...)

        coEvery { productRepository.existsBySku("SKU-001") } returns true

        shouldThrow<BusinessRuleViolationException> {
            useCase.execute(command)
        }
    }
})
```

**Integration Tests:**
```kotlin
@Testcontainers
class ProductControllerIntegrationTest : StringSpec({
    val postgresContainer = PostgreSQLContainer<Nothing>("postgres:17")
    val redisContainer = GenericContainer<Nothing>("redis:7")

    beforeSpec {
        postgresContainer.start()
        redisContainer.start()
    }

    afterSpec {
        postgresContainer.stop()
        redisContainer.stop()
    }

    "should create product via API" {
        val response = webTestClient.post()
            .uri("/api/products")
            .bodyValue(CreateProductCommand(...))
            .exchange()
            .expectStatus().isCreated
            .expectBody(UUID::class.java)
            .returnResult()

        response.responseBody shouldNotBe null
    }
})
```

## Common Tasks

### Adding a New Aggregate to Existing Context

1. **Create domain model** in `<context>/domain/model/`:
   ```kotlin
   class Category private constructor(...) : AggregateRoot<UUID>(id) {
       companion object {
           fun create(...): Category { ... }
       }
   }
   ```

2. **Define repository port** in `<context>/domain/repository/`:
   ```kotlin
   interface CategoryRepository {
       suspend fun save(category: Category): Category
       suspend fun findById(id: UUID): Category?
       // ...
   }
   ```

3. **Implement R2DBC repository** in `<context>/infrastructure/persistence/`:
   ```kotlin
   @Repository
   class R2dbcCategoryRepository(
       private val databaseClient: DatabaseClient
   ) : CategoryRepository { ... }
   ```

4. **Create use cases** in `<context>/application/usecase/`:
   ```kotlin
   @Service
   class CreateCategoryUseCase(
       private val categoryRepository: CategoryRepository
   ) { ... }
   ```

5. **Add REST controller** in `<context>/infrastructure/web/`:
   ```kotlin
   @RestController
   @RequestMapping("/api/categories")
   class CategoryController(...) { ... }
   ```

6. **Create migration** in `src/main/resources/db/migration/`:
   ```sql
   -- V13__catalog__add_categories_table.sql
   CREATE TABLE catalog.categories (...);
   ```

### Adding a New Bounded Context

1. **Add schema** to `V1__create_all_schemas.sql`:
   ```sql
   CREATE SCHEMA IF NOT EXISTS newcontext;
   ```

2. **Create package structure**:
   ```
   com.shopnow.newcontext/
   ├── domain/
   │   ├── model/
   │   └── repository/
   ├── application/
   │   ├── command/
   │   ├── dto/
   │   └── usecase/
   └── infrastructure/
       ├── persistence/
       └── web/
   ```

3. **Create migration**:
   ```sql
   -- V13__newcontext__create_tables.sql
   CREATE TABLE newcontext.main_table (...);
   ```

4. **Update application.yml** to include new schema in Flyway:
   ```yaml
   spring:
     flyway:
       schemas:
         - ...
         - newcontext
   ```

5. **Follow same patterns** as existing contexts (catalog, identity)

### Working with Money

```kotlin
// Creating Money
val price = Money.of(BigDecimal("99.99"), "USD")
val discount = Money.of(10.00, "USD")

// Arithmetic operations
val finalPrice = price.subtract(discount)  // $89.99
val total = price.multiply(3)              // $299.97

// Validation
val invalid = Money.of(-10.00, "USD")  // Throws IllegalArgumentException

// Currency matching
val euro = Money.of(50.00, "EUR")
val sum = price.add(euro)  // Throws IllegalArgumentException (different currencies)
```

### Working with Domain Events

```kotlin
// In aggregate
class Order private constructor(...) : AggregateRoot<UUID>(id) {
    fun confirm() {
        require(status == OrderStatus.PENDING) { "Can only confirm pending orders" }
        status = OrderStatus.CONFIRMED
        registerEvent(OrderConfirmedEvent(id, customerId, totalAmount))
    }
}

// In use case
@Service
class ConfirmOrderUseCase(
    private val orderRepository: OrderRepository,
    private val eventPublisher: EventPublisher  // Future: Kafka, RabbitMQ
) {
    suspend fun execute(orderId: UUID) {
        val order = orderRepository.findById(orderId)
            ?: throw EntityNotFoundException("Order not found")

        order.confirm()
        orderRepository.save(order)

        // Publish events
        val events = order.pullDomainEvents()
        eventPublisher.publishAll(events)
    }
}
```

## Architectural Decisions & Trade-offs

### ✅ Strengths

1. **True Hexagonal Architecture**
   - Domain layer is 100% framework-independent
   - Easy to test domain logic in isolation
   - Can swap infrastructure without changing domain

2. **Reactive End-to-End**
   - Non-blocking from HTTP to database
   - High throughput and scalability
   - Efficient resource utilization

3. **Schema Isolation**
   - Each context has its own database schema
   - Clear boundaries between contexts
   - Supports eventual migration to microservices

4. **Event-Driven**
   - Complete audit trail of all changes
   - Event sourcing ready
   - Supports asynchronous communication

5. **DDD Compliance**
   - Behavior-rich aggregates (not anemic models)
   - Clear ubiquitous language
   - Domain events for business occurrences

6. **Type Safety**
   - Kotlin with strong typing
   - Value objects prevent primitive obsession
   - Compile-time safety

### ⚠️ Trade-offs & Considerations

1. **Complexity**
   - Hexagonal + DDD + Reactive = steep learning curve
   - More layers and abstractions
   - Requires disciplined team

2. **Reflection for Aggregates**
   - Uses reflection to reconstruct aggregates from database
   - Necessary to preserve private constructors in domain layer
   - Small performance overhead (acceptable)

3. **Event Processing**
   - Currently in-process (not async message broker)
   - Future: Migrate to Kafka/RabbitMQ for true async
   - Event store ready for this migration

4. **Schema-per-Context**
   - More complex migrations
   - No cross-schema joins (must use events or APIs)
   - Trade isolation for convenience

5. **R2DBC Maturity**
   - Less mature than JDBC
   - Fewer tools and libraries
   - Some advanced features missing

6. **No CQRS Yet**
   - Using same models for commands and queries
   - Future: Separate read and write models
   - Event store supports CQRS migration

## Future Architecture Evolution

### Phase 1: Current State (Modular Monolith) ✅

```
Single Spring Boot Application
├── 10 bounded contexts
├── Schema-per-context isolation
├── Event store ready
└── Reactive end-to-end
```

**Status:** ✅ Implemented for catalog and identity contexts

### Phase 2: Complete Modular Monolith (Next)

```
Complete Implementation
├── All 10 contexts fully implemented
├── Inter-context event handling
├── CQRS for read-heavy contexts (catalog)
├── Async event processing (Kafka/RabbitMQ)
└── Complete test coverage
```

**Next Steps:**
1. Implement remaining contexts (shopping, orders, payment, shipping, etc.)
2. Add event publishers and subscribers
3. Implement CQRS for catalog context
4. Add integration tests for cross-context flows

### Phase 3: Microservices Migration (Future)

```
Microservices Architecture
├── Each context → Independent service
│   ├── Own database instance
│   ├── Own deployment unit
│   ├── Own scaling policy
│   └── Own technology stack (if needed)
├── API Gateway (Kong, Spring Cloud Gateway)
├── Message Broker (Kafka)
├── Service Mesh (Istio, Linkerd)
└── Distributed Tracing (Jaeger, Zipkin)
```

**Migration Path:**
1. Extract bounded contexts to separate services
2. Deploy event bus (Kafka)
3. Implement saga pattern for distributed transactions
4. Add service discovery (Consul, Eureka)
5. Deploy API gateway

### Phase 4: Advanced Patterns (Future)

- Full Event Sourcing for all aggregates
- CQRS across all contexts
- GraphQL federation for unified API
- Kubernetes deployment with Helm charts
- Multi-region deployment

## Quick Reference

### File Locations

| Component | Location |
|-----------|----------|
| Aggregates | `com.shopnow.<context>/domain/model/` |
| Value Objects (shared) | `com.shopnow.shared.kernel.domain.valueobject/` |
| Domain Events | `com.shopnow.<context>/domain/model/events/` |
| Repository Ports | `com.shopnow.<context>/domain/repository/` |
| Use Cases | `com.shopnow.<context>/application/usecase/` |
| Commands | `com.shopnow.<context>/application/command/` |
| DTOs | `com.shopnow.<context>/application/dto/` |
| R2DBC Repositories | `com.shopnow.<context>/infrastructure/persistence/` |
| Controllers | `com.shopnow.<context>/infrastructure/web/` |
| Migrations | `src/main/resources/db/migration/` |
| Config | `src/main/resources/application.yml` |

### Key Interfaces

```kotlin
// Aggregate Root
abstract class AggregateRoot<ID>(val id: ID)

// Value Object
interface ValueObject

// Domain Event
abstract class BaseDomainEvent(val aggregateId: UUID, val eventType: String)

// Repository
interface Repository<T, ID> {
    suspend fun save(entity: T): T
    suspend fun findById(id: ID): T?
    suspend fun delete(id: ID)
}
```

### Common Gradle Commands

```bash
# Run app
./gradlew bootRun

# Run tests
./gradlew test

# Run specific test class
./gradlew test --tests "ProductTest"

# Build JAR
./gradlew build

# Clean + Build
./gradlew clean build

# Run Flyway migration
./gradlew flywayMigrate

# Check migration status
./gradlew flywayInfo

# Generate Flyway baseline
./gradlew flywayBaseline

# Repair Flyway metadata
./gradlew flywayRepair
```

### Docker Commands

```bash
# Start all services
docker-compose up -d

# Start with dev tools
docker-compose --profile dev up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# Restart PostgreSQL
docker-compose restart postgres

# Access PostgreSQL CLI
docker-compose exec postgres psql -U shopnow -d shopnow
```

---

## Summary

**ShopNow** is a **production-grade, reactive e-commerce backend** architected as a **modular monolith** with:

- **Hexagonal Architecture** for clean separation of concerns
- **Domain-Driven Design** for business-centric modeling
- **Event-Driven Architecture** for scalability and decoupling
- **Reactive Programming** for high-performance, non-blocking I/O
- **Schema-per-Context** for bounded context isolation

The system is designed to evolve from **modular monolith → microservices** when business needs demand it, with complete event sourcing infrastructure already in place.

**Current Implementation Status:**
- ✅ Core architecture established
- ✅ Catalog context fully implemented
- ✅ Identity context fully implemented
- ✅ All database schemas created
- 🟡 8 contexts awaiting implementation
- 🟡 Event-driven inter-context communication (in progress)

This architecture balances **sophistication with pragmatism**, demonstrating advanced patterns while maintaining practical implementation and developer experience.
