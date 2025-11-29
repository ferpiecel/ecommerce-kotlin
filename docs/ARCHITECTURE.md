# ShopNow Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Data Flow](#data-flow)
6. [Communication Patterns](#communication-patterns)
7. [Infrastructure](#infrastructure)
8. [Security](#security)
9. [Testing Strategy](#testing-strategy)
10. [Deployment](#deployment)

## System Overview

ShopNow is an e-commerce platform built using **Hexagonal Architecture** (Ports & Adapters) and **Domain-Driven Design** (DDD) principles, organized into multiple **Bounded Contexts**.

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Client Layer                             │
│  (Web Browser, Mobile App, External Systems)                    │
└────────────────────────┬────────────────────────────────────────┘
                         │ HTTPS/REST/GraphQL
┌────────────────────────▼────────────────────────────────────────┐
│                     API Gateway / Load Balancer                  │
└────────────────────────┬────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
┌───────▼───────┐ ┌─────▼──────┐ ┌──────▼───────┐
│   Catalog     │ │   Order    │ │  Identity    │ ... (More Contexts)
│   Service     │ │  Service   │ │   Service    │
│ (Spring Boot) │ │(Spring Boot)│ │(Spring Boot) │
└───────┬───────┘ └─────┬──────┘ └──────┬───────┘
        │               │                │
        └───────────────┼────────────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
    ┌─────────▼────────┐  ┌──────▼────────┐
    │   PostgreSQL     │  │     Redis     │
    │   (Schemas per   │  │    (Cache)    │
    │    Context)      │  │               │
    └──────────────────┘  └───────────────┘
              │
    ┌─────────▼────────┐
    │   Event Store    │
    │   (PostgreSQL)   │
    └──────────────────┘
```

### Architecture Layers

Each bounded context follows the same layered architecture:

```
┌─────────────────────────────────────────────────────────┐
│                   Presentation Layer                     │
│              (REST Controllers, GraphQL)                 │
│                    Input Adapters                        │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                  Application Layer                       │
│           (Use Cases, Command/Query Handlers)            │
│              Business Orchestration                      │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                    Domain Layer                          │
│    (Aggregates, Entities, Value Objects, Services)      │
│              Core Business Logic                         │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                Infrastructure Layer                      │
│        (Database, Messaging, External Services)          │
│                  Output Adapters                         │
└─────────────────────────────────────────────────────────┘
```

## Architecture Principles

### 1. Separation of Concerns
- Each layer has a clear responsibility
- Domain logic is isolated from infrastructure
- No framework dependencies in domain layer

### 2. Dependency Inversion
- Dependencies point inward (toward domain)
- Domain defines interfaces (ports)
- Infrastructure implements interfaces (adapters)

### 3. Single Responsibility
- Each bounded context has one clear purpose
- Each aggregate manages one consistency boundary
- Each use case does one thing

### 4. Explicit Boundaries
- Bounded contexts are isolated
- Communication through well-defined interfaces
- No direct database sharing between contexts

### 5. Event-Driven Design
- Asynchronous communication between contexts
- Domain events capture business occurrences
- Eventual consistency where appropriate

## Technology Stack

### Backend

#### Core Framework
```yaml
Spring Boot: 3.4.0
Kotlin: 2.1.0
Java: 21
```

#### Web Layer
```yaml
Spring WebFlux: Reactive web framework
- Supports reactive programming model
- Handles sync and async requests
- Non-blocking I/O
```

#### Data Access
```yaml
Spring Data R2DBC: Reactive database access
- Async queries with Mono/Flux
- Non-blocking database operations

Spring Data JDBC: Synchronous database access
- Traditional blocking operations
- Simple queries

PostgreSQL: 17
- Multiple schemas (one per context)
- JSONB support for flexibility
- Full ACID compliance

Redis: 7
- Caching layer
- Session storage
- Rate limiting
```

#### Messaging
```yaml
Spring Cloud Stream: Message abstraction
Kafka or RabbitMQ: Event broker
- Domain events
- Inter-context communication
- Event sourcing
```

#### Database Migrations
```yaml
Flyway: Schema migrations
- Version-controlled migrations
- Schema-per-context organization
```

#### Testing
```yaml
JUnit 5: Test framework
Kotest: Kotlin testing library
MockK: Kotlin mocking
Testcontainers: Integration testing with Docker
```

### DevOps

```yaml
Docker: Containerization
Docker Compose: Local development
Gradle: Build tool (Kotlin DSL)
```

## Project Structure

### Multi-Module Structure

```
shopnow/
├── buildSrc/                              # Build configuration
├── shared/                                # Shared kernel
│   ├── domain/
│   │   ├── AggregateRoot.kt
│   │   ├── Entity.kt
│   │   ├── ValueObject.kt
│   │   ├── DomainEvent.kt
│   │   └── common/
│   │       ├── Money.kt
│   │       ├── Currency.kt
│   │       └── Identifier.kt
│   ├── application/
│   │   ├── UseCase.kt
│   │   ├── Command.kt
│   │   ├── Query.kt
│   │   └── EventPublisher.kt
│   └── infrastructure/
│       ├── event/
│       │   └── EventBus.kt
│       └── persistence/
│           └── BaseRepository.kt
│
├── contexts/                              # Bounded contexts
│   ├── catalog/
│   │   ├── domain/
│   │   │   ├── model/
│   │   │   │   ├── Product.kt          # Aggregate Root
│   │   │   │   ├── ProductId.kt
│   │   │   │   ├── Category.kt
│   │   │   │   └── Money.kt
│   │   │   ├── repository/
│   │   │   │   └── ProductRepository.kt # Port
│   │   │   ├── event/
│   │   │   │   ├── ProductCreated.kt
│   │   │   │   └── PriceChanged.kt
│   │   │   └── service/
│   │   │       └── PricingService.kt
│   │   ├── application/
│   │   │   ├── command/
│   │   │   │   ├── CreateProductCommand.kt
│   │   │   │   └── CreateProductHandler.kt
│   │   │   ├── query/
│   │   │   │   ├── GetProductQuery.kt
│   │   │   │   ├── GetProductHandler.kt
│   │   │   │   └── ProductDTO.kt
│   │   │   └── event/
│   │   │       └── ProductEventHandler.kt
│   │   └── infrastructure/
│   │       ├── adapter/
│   │       │   ├── input/
│   │       │   │   └── rest/
│   │       │   │       ├── ProductController.kt
│   │       │   │       └── CreateProductRequest.kt
│   │       │   └── output/
│   │       │       ├── persistence/
│   │       │       │   ├── r2dbc/
│   │       │       │   │   ├── ProductEntity.kt
│   │       │       │   │   ├── ProductR2dbcRepository.kt
│   │       │       │   │   └── ProductRepositoryAdapter.kt
│   │       │       │   └── jdbc/
│   │       │       │       └── ProductJdbcRepository.kt
│   │       │       └── messaging/
│   │       │           └── ProductEventPublisher.kt
│   │       └── config/
│   │           ├── CatalogConfiguration.kt
│   │           └── DatabaseConfiguration.kt
│   │
│   ├── identity/
│   │   └── [same structure]
│   ├── shopping/
│   │   └── [same structure]
│   ├── orders/
│   │   └── [same structure]
│   └── [other contexts...]
│
├── application/                           # Main application
│   ├── src/main/kotlin/
│   │   └── com/shopnow/
│   │       ├── ShopNowApplication.kt
│   │       └── config/
│   │           ├── WebFluxConfig.kt
│   │           ├── SecurityConfig.kt
│   │           └── EventConfig.kt
│   └── src/main/resources/
│       ├── application.yml
│       ├── application-dev.yml
│       ├── application-prod.yml
│       └── db/migration/
│           ├── catalog/
│           │   ├── V1__catalog__create_schema.sql
│           │   └── V2__catalog__create_products.sql
│           ├── identity/
│           │   └── V1__identity__create_schema.sql
│           └── [other contexts...]
│
├── docs/                                  # Documentation
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── HEXAGONAL_ARCHITECTURE.md
│   ├── DDD_GUIDE.md
│   ├── BOUNDED_CONTEXTS.md
│   └── ONBOARDING.md
│
├── docker-compose.yml
├── build.gradle.kts
├── settings.gradle.kts
└── README.md
```

### File Naming Conventions

```
Domain:
- Aggregates: Product.kt, Order.kt
- Value Objects: Money.kt, ProductId.kt
- Events: ProductCreated.kt, OrderPlaced.kt
- Repositories (interfaces): ProductRepository.kt

Application:
- Commands: CreateProductCommand.kt
- Handlers: CreateProductHandler.kt
- Queries: GetProductQuery.kt
- DTOs: ProductDTO.kt

Infrastructure:
- Controllers: ProductController.kt
- Entities: ProductEntity.kt
- Adapters: ProductRepositoryAdapter.kt
- Requests/Responses: CreateProductRequest.kt, ProductResponse.kt
```

## Data Flow

### Synchronous Flow (Command - Write Operation)

```
1. Client Request
   │
   ▼
2. ProductController (Input Adapter)
   │ - Validates request
   │ - Maps to Command
   ▼
3. CreateProductHandler (Application)
   │ - Orchestrates use case
   │ - Calls domain
   ▼
4. Product Aggregate (Domain)
   │ - Business logic
   │ - Creates domain event
   ▼
5. ProductRepository (Output Port)
   │ - Defined as interface in domain
   ▼
6. ProductRepositoryAdapter (Output Adapter)
   │ - R2DBC implementation
   │ - Saves to database
   ▼
7. EventPublisher
   │ - Publishes ProductCreated event
   ▼
8. Response to Client
```

### Synchronous Flow (Query - Read Operation)

```
1. Client Request
   │
   ▼
2. ProductController (Input Adapter)
   │ - Creates Query object
   ▼
3. GetProductHandler (Application)
   │ - Calls repository
   ▼
4. ProductRepository (Output Port)
   │
   ▼
5. ProductRepositoryAdapter (Output Adapter)
   │ - R2DBC query (async)
   │ - Returns ProductDTO
   ▼
6. Response to Client
```

### Asynchronous Flow (Event-Driven)

```
Catalog Context                   Order Context
─────────────────                 ────────────────

1. ProductPriceChanged
   Event Published
        │
        ▼
   Event Bus (Kafka)
        │
        ▼                         2. OrderEventListener
                                     │ - Receives event
                                     ▼
                                  3. UpdateOrderPriceHandler
                                     │ - Loads Order aggregate
                                     │ - Updates cached price
                                     ▼
                                  4. OrderRepository
                                     │ - Saves updated order
                                     ▼
                                     Done
```

## Communication Patterns

### 1. Synchronous (REST with WebFlux)

```kotlin
@RestController
@RequestMapping("/api/products")
class ProductController(
    private val createProduct: CreateProductUseCase,
    private val getProduct: GetProductUseCase
) {
    // Async endpoint returning Mono
    @PostMapping
    suspend fun create(@RequestBody request: CreateProductRequest): ResponseEntity<ProductResponse> {
        val command = request.toCommand()
        val productId = createProduct.execute(command)
        return ResponseEntity.created(URI.create("/api/products/${productId.value}"))
            .body(ProductResponse(productId.value.toString()))
    }

    // Async endpoint returning Mono
    @GetMapping("/{id}")
    suspend fun getById(@PathVariable id: String): ResponseEntity<ProductDTO> {
        val query = GetProductQuery(id)
        val product = getProduct.execute(query) ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok(product)
    }

    // Async endpoint returning Flux
    @GetMapping
    fun getAll(): Flux<ProductDTO> {
        return getAllProducts.execute()
    }
}
```

### 2. Asynchronous (Event-Driven)

```kotlin
// Publishing events
@Service
class CreateProductHandler(
    private val productRepository: ProductRepository,
    private val eventPublisher: EventPublisher
) {
    suspend fun execute(command: CreateProductCommand): ProductId {
        val product = Product.create(...)
        productRepository.save(product)

        // Publish event asynchronously
        product.events.forEach { event ->
            eventPublisher.publish(event)
        }

        return product.id
    }
}

// Consuming events
@Component
class OrderEventListener(
    private val updateOrderPrice: UpdateOrderPriceHandler
) {
    @EventHandler
    suspend fun on(event: ProductPriceChanged) {
        // Handle event asynchronously
        updateOrderPrice.execute(
            UpdateOrderPriceCommand(
                productId = event.productId,
                newPrice = event.newPrice
            )
        )
    }
}
```

### 3. Database Access Patterns

#### R2DBC (Async/Reactive)

```kotlin
@Repository
interface ProductR2dbcRepository : R2dbcRepository<ProductEntity, UUID> {
    fun findByCategoryId(categoryId: UUID): Flux<ProductEntity>

    @Query("SELECT * FROM catalog.products WHERE price <= :maxPrice")
    fun findByPriceLessThan(maxPrice: BigDecimal): Flux<ProductEntity>
}

// Usage
class ProductRepositoryAdapter(
    private val r2dbcRepository: ProductR2dbcRepository
) : ProductRepository {
    override suspend fun save(product: Product): Product {
        val entity = mapper.toEntity(product)
        val saved = r2dbcRepository.save(entity) // Returns Mono<ProductEntity>
        return mapper.toDomain(saved)
    }

    override fun findAll(): Flow<Product> {
        return r2dbcRepository.findAll() // Returns Flux<ProductEntity>
            .map { mapper.toDomain(it) }
            .asFlow() // Convert to Kotlin Flow
    }
}
```

#### JDBC (Sync) - for simple operations

```kotlin
@Repository
class ProductJdbcRepository(
    private val jdbcTemplate: JdbcTemplate
) {
    fun existsBySku(sku: String): Boolean {
        return jdbcTemplate.queryForObject(
            "SELECT EXISTS(SELECT 1 FROM catalog.products WHERE sku = ?)",
            Boolean::class.java,
            sku
        ) ?: false
    }
}
```

## Infrastructure

### Database Design

#### Schema Organization

Each bounded context has its own schema:

```sql
-- Catalog Context
CREATE SCHEMA catalog;

-- Identity Context
CREATE SCHEMA identity;

-- Order Context
CREATE SCHEMA orders;

-- etc.
```

#### Migration Strategy

Migrations organized by context:

```
db/migration/
├── catalog/
│   ├── V1__catalog__create_schema.sql
│   ├── V2__catalog__create_products_table.sql
│   └── V3__catalog__add_sku_index.sql
├── identity/
│   ├── V1__identity__create_schema.sql
│   └── V2__identity__create_users_table.sql
└── orders/
    ├── V1__orders__create_schema.sql
    └── V2__orders__create_orders_table.sql
```

Naming convention: `V{version}__{context}__{description}.sql`

### Caching Strategy (Redis)

```kotlin
@Service
class CachedProductRepository(
    private val repository: ProductRepository,
    private val redisTemplate: ReactiveRedisTemplate<String, ProductDTO>
) {
    suspend fun findById(id: ProductId): Product? {
        val cacheKey = "product:${id.value}"

        // Try cache first
        val cached = redisTemplate.opsForValue().get(cacheKey).awaitFirstOrNull()
        if (cached != null) return mapper.toDomain(cached)

        // Cache miss - query database
        val product = repository.findById(id) ?: return null

        // Update cache
        redisTemplate.opsForValue()
            .set(cacheKey, mapper.toDTO(product), Duration.ofHours(1))
            .awaitFirstOrNull()

        return product
    }
}
```

### Event Store

Domain events are persisted for audit and event sourcing:

```sql
CREATE SCHEMA events;

CREATE TABLE events.domain_events (
    id UUID PRIMARY KEY,
    event_type VARCHAR(255) NOT NULL,
    aggregate_id UUID NOT NULL,
    aggregate_type VARCHAR(255) NOT NULL,
    event_data JSONB NOT NULL,
    occurred_at TIMESTAMP NOT NULL,
    published_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_events_aggregate ON events.domain_events(aggregate_id, aggregate_type);
CREATE INDEX idx_events_type ON events.domain_events(event_type);
CREATE INDEX idx_events_occurred ON events.domain_events(occurred_at);
```

## Security

### Authentication & Authorization

```kotlin
@Configuration
@EnableWebFluxSecurity
class SecurityConfig {

    @Bean
    fun securityWebFilterChain(http: ServerHttpSecurity): SecurityWebFilterChain {
        return http
            .authorizeExchange()
                .pathMatchers("/api/public/**").permitAll()
                .pathMatchers("/api/admin/**").hasRole("ADMIN")
                .pathMatchers("/api/**").authenticated()
            .and()
            .oauth2ResourceServer()
                .jwt()
            .and()
            .build()
    }
}
```

### Input Validation

```kotlin
@PostMapping
suspend fun create(
    @RequestBody @Valid request: CreateProductRequest
): ResponseEntity<ProductResponse> {
    // Spring validation applied
    // Domain validation in aggregate
}

data class CreateProductRequest(
    @field:NotBlank val name: String,
    @field:Positive val price: BigDecimal,
    @field:NotBlank val sku: String
)
```

## Testing Strategy

### 1. Unit Tests (Domain Layer)

```kotlin
class ProductTest {
    @Test
    fun `should create product with valid data`() {
        val product = Product.create(
            name = ProductName("Laptop"),
            price = Money(BigDecimal("999.99")),
            categoryId = CategoryId.generate(),
            initialStock = Stock(10)
        )

        assertThat(product.name.value).isEqualTo("Laptop")
        assertThat(product.events).hasSize(1)
    }
}
```

### 2. Integration Tests (Application Layer)

```kotlin
@SpringBootTest
class CreateProductHandlerTest {
    @MockkBean
    lateinit var repository: ProductRepository

    @Autowired
    lateinit var handler: CreateProductHandler

    @Test
    fun `should create product and publish event`() = runBlocking {
        coEvery { repository.save(any()) } returns mockk()

        val command = CreateProductCommand(...)
        val productId = handler.execute(command)

        assertThat(productId).isNotNull()
        coVerify { repository.save(any()) }
    }
}
```

### 3. E2E Tests (with Testcontainers)

```kotlin
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class ProductApiTest {

    @Container
    val postgres = PostgreSQLContainer("postgres:17")

    @Autowired
    lateinit var webTestClient: WebTestClient

    @Test
    fun `should create and retrieve product`() {
        // Create
        val createRequest = CreateProductRequest(...)
        val response = webTestClient.post()
            .uri("/api/products")
            .bodyValue(createRequest)
            .exchange()
            .expectStatus().isCreated
            .expectBody<ProductResponse>()
            .returnResult()

        // Retrieve
        val productId = response.responseBody!!.id
        webTestClient.get()
            .uri("/api/products/$productId")
            .exchange()
            .expectStatus().isOk
            .expectBody<ProductDTO>()
    }
}
```

## Deployment

### Docker Composition

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:17
    environment:
      POSTGRES_DB: shopnow
      POSTGRES_USER: shopnow
      POSTGRES_PASSWORD: shopnow
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  kafka:
    image: confluentinc/cp-kafka:latest
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"

  shopnow-app:
    build: .
    depends_on:
      - postgres
      - redis
      - kafka
    environment:
      SPRING_PROFILES_ACTIVE: prod
      DB_HOST: postgres
      REDIS_HOST: redis
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    ports:
      - "8080:8080"

volumes:
  postgres_data:
```

### Environment Configuration

```yaml
# application.yml
spring:
  application:
    name: shopnow
  r2dbc:
    url: r2dbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:shopnow}
    username: ${DB_USER:shopnow}
    password: ${DB_PASSWORD:shopnow}
  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}
  cloud:
    stream:
      kafka:
        binder:
          brokers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}
```

---

## Summary

ShopNow implements:
- **Hexagonal Architecture**: Clear separation between business logic and infrastructure
- **DDD**: Rich domain models organized into bounded contexts
- **Reactive Programming**: WebFlux for async/reactive endpoints
- **Event-Driven**: Asynchronous communication between contexts
- **Microservices-Ready**: Each context can be extracted to a separate service
- **Testable**: Clear layers enable comprehensive testing
- **Scalable**: Async processing, caching, and event-driven design

---

**Version**: 1.0
**Last Updated**: 2025-11-29
