# Developer Onboarding Guide

Welcome to ShopNow! This guide will help you get up to speed with our e-commerce platform.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Getting Started](#getting-started)
3. [Understanding the Architecture](#understanding-the-architecture)
4. [Development Workflow](#development-workflow)
5. [Coding Standards](#coding-standards)
6. [Common Tasks](#common-tasks)
7. [Troubleshooting](#troubleshooting)
8. [Resources](#resources)

## Prerequisites

### Required Software

```bash
# Java Development Kit
Java 21 or higher

# Build Tool
Gradle 8.10+ (wrapper included)

# IDE (recommended)
IntelliJ IDEA Ultimate (for Kotlin support)

# Docker & Docker Compose
Docker 24+
Docker Compose 2.20+

# Version Control
Git
```

### Recommended Tools

```bash
# API Testing
Postman or Insomnia

# Database Client
DBeaver or pgAdmin

# Redis Client
RedisInsight

# Kafka Client (if using Kafka)
Kafka Tool or Offset Explorer
```

### Knowledge Prerequisites

You should be familiar with:
- **Kotlin** - Primary language
- **Spring Boot & Spring WebFlux** - Framework
- **PostgreSQL** - Database
- **Domain-Driven Design** - Core architectural pattern
- **Hexagonal Architecture** - Architectural style
- **Reactive Programming** - Async/reactive patterns

Don't worry if you're not an expert! We have comprehensive documentation to help you learn.

## Getting Started

### 1. Clone the Repository

```bash
git clone <repository-url>
cd shopnow
```

### 2. Start Infrastructure

```bash
# Start PostgreSQL, Redis, and Kafka
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 3. Run Database Migrations

```bash
./gradlew flywayMigrate
```

### 4. Build the Application

```bash
./gradlew build
```

### 5. Run the Application

```bash
./gradlew bootRun
```

Or run from IntelliJ IDEA:
- Open `ShopNowApplication.kt`
- Click the green play button

### 6. Verify Setup

```bash
# Health check
curl http://localhost:8080/actuator/health

# API documentation (OpenAPI/Swagger)
open http://localhost:8080/swagger-ui.html
```

## Understanding the Architecture

### Required Reading (in order)

1. **[PRD.md](PRD.md)** - Product requirements and business context
2. **[HEXAGONAL_ARCHITECTURE.md](HEXAGONAL_ARCHITECTURE.md)** - Architecture pattern
3. **[DDD_GUIDE.md](DDD_GUIDE.md)** - Domain-Driven Design principles
4. **[BOUNDED_CONTEXTS.md](BOUNDED_CONTEXTS.md)** - Context details
5. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture

### Quick Architecture Overview

```
┌─────────────────────────────────────────────┐
│         Hexagonal Architecture              │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────┐         ┌──────────────┐ │
│  │   REST API  │────────▶│ Application  │ │
│  │  (Adapter)  │         │   (Use Case) │ │
│  └─────────────┘         └───────┬──────┘ │
│                                  │         │
│                          ┌───────▼──────┐  │
│                          │    Domain    │  │
│                          │  (Business)  │  │
│                          └───────┬──────┘  │
│                                  │         │
│  ┌─────────────┐         ┌──────▼───────┐ │
│  │  Database   │◀────────│  Repository  │ │
│  │  (Adapter)  │         │   (Port)     │ │
│  └─────────────┘         └──────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

**Key Concepts:**
- **Domain Layer**: Pure business logic (no framework dependencies)
- **Application Layer**: Orchestrates use cases
- **Infrastructure Layer**: Technical concerns (DB, HTTP, etc.)
- **Ports**: Interfaces (contracts)
- **Adapters**: Implementations

### Bounded Contexts

Our system is divided into these contexts:

1. **Catalog** - Products and categories
2. **Identity** - Users and authentication
3. **Shopping** - Cart, wishlist, reviews
4. **Orders** - Order management
5. **Payment** - Payment processing
6. **Shipping** - Shipping and delivery
7. **Promotion** - Discounts and coupons
8. **Partner** - Affiliates and suppliers
9. **Notification** - Alerts and messages

Each context is independent and communicates via events.

## Development Workflow

### Working on a New Feature

#### 1. Understand the Requirement

- Read the ticket/issue
- Identify which bounded context(s) are involved
- Discuss with team if unclear

#### 2. Design Domain Model

```kotlin
// Example: Adding a discount feature to Product

// 1. Start with domain (no infrastructure!)
// domain/model/Discount.kt
data class Discount(
    val percentage: Percentage,
    val validUntil: Instant
) {
    fun apply(price: Money): Money {
        val discountAmount = price.amount * percentage.value / BigDecimal(100)
        return Money(price.amount - discountAmount, price.currency)
    }

    fun isValid(): Boolean = Instant.now() < validUntil
}

// 2. Add to aggregate
class Product {
    var discount: Discount? = null

    fun applyDiscount(discount: Discount) {
        require(discount.isValid()) { "Cannot apply expired discount" }
        this.discount = discount
        addEvent(DiscountApplied(id, discount))
    }

    fun currentPrice(): Money {
        return discount?.apply(price) ?: price
    }
}
```

#### 3. Create Use Case

```kotlin
// application/command/ApplyDiscountCommand.kt
data class ApplyDiscountCommand(
    val productId: String,
    val discountPercentage: BigDecimal,
    val validUntil: Instant
)

// application/command/ApplyDiscountHandler.kt
@Service
class ApplyDiscountHandler(
    private val productRepository: ProductRepository,
    private val eventPublisher: EventPublisher
) {
    @Transactional
    suspend fun execute(command: ApplyDiscountCommand): Unit {
        // Load aggregate
        val productId = ProductId(UUID.fromString(command.productId))
        val product = productRepository.findById(productId)
            ?: throw ProductNotFoundException(productId)

        // Execute business logic
        val discount = Discount(
            percentage = Percentage(command.discountPercentage),
            validUntil = command.validUntil
        )
        product.applyDiscount(discount)

        // Save
        productRepository.save(product)

        // Publish events
        product.events.forEach { eventPublisher.publish(it) }
    }
}
```

#### 4. Create Controller

```kotlin
// infrastructure/adapter/input/rest/ProductController.kt
@RestController
@RequestMapping("/api/products")
class ProductController(
    private val applyDiscount: ApplyDiscountHandler
) {
    @PostMapping("/{id}/discount")
    suspend fun applyDiscount(
        @PathVariable id: String,
        @RequestBody @Valid request: ApplyDiscountRequest
    ): ResponseEntity<Void> {
        val command = ApplyDiscountCommand(
            productId = id,
            discountPercentage = request.percentage,
            validUntil = request.validUntil
        )

        applyDiscount.execute(command)

        return ResponseEntity.ok().build()
    }
}

data class ApplyDiscountRequest(
    @field:Min(0) @field:Max(100) val percentage: BigDecimal,
    @field:Future val validUntil: Instant
)
```

#### 5. Write Tests

```kotlin
// Test domain logic
class ProductTest {
    @Test
    fun `should apply valid discount`() {
        val product = Product.create(...)
        val discount = Discount(
            percentage = Percentage(BigDecimal("10")),
            validUntil = Instant.now().plus(Duration.ofDays(7))
        )

        product.applyDiscount(discount)

        assertThat(product.currentPrice().amount)
            .isEqualTo(BigDecimal("899.99")) // 999.99 - 10%
    }

    @Test
    fun `should not apply expired discount`() {
        val product = Product.create(...)
        val expiredDiscount = Discount(
            percentage = Percentage(BigDecimal("10")),
            validUntil = Instant.now().minus(Duration.ofDays(1))
        )

        assertThrows<IllegalArgumentException> {
            product.applyDiscount(expiredDiscount)
        }
    }
}

// Test use case
@SpringBootTest
class ApplyDiscountHandlerTest {
    @MockkBean
    lateinit var repository: ProductRepository

    @Autowired
    lateinit var handler: ApplyDiscountHandler

    @Test
    fun `should apply discount and publish event`() = runBlocking {
        val product = Product.create(...)
        coEvery { repository.findById(any()) } returns product
        coEvery { repository.save(any()) } returns product

        val command = ApplyDiscountCommand(...)
        handler.execute(command)

        coVerify { repository.save(any()) }
    }
}

// Test API
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class ProductApiTest {
    @Test
    fun `should apply discount via API`() {
        webTestClient.post()
            .uri("/api/products/{id}/discount", productId)
            .bodyValue(ApplyDiscountRequest(...))
            .exchange()
            .expectStatus().isOk
    }
}
```

#### 6. Create Migration (if needed)

```sql
-- db/migration/catalog/V4__catalog__add_discount_to_products.sql
ALTER TABLE catalog.products
ADD COLUMN discount_percentage DECIMAL(5, 2),
ADD COLUMN discount_valid_until TIMESTAMP;

CREATE INDEX idx_products_discount ON catalog.products(discount_valid_until)
WHERE discount_percentage IS NOT NULL;
```

### Git Workflow

```bash
# 1. Create feature branch
git checkout -b feature/apply-product-discount

# 2. Make changes and commit frequently
git add .
git commit -m "feat(catalog): add discount domain model"
git commit -m "feat(catalog): add apply discount use case"
git commit -m "feat(catalog): add discount API endpoint"

# 3. Push and create PR
git push origin feature/apply-product-discount
# Create PR via GitHub/GitLab
```

### Commit Message Convention

```
<type>(<scope>): <subject>

Types:
- feat: New feature
- fix: Bug fix
- refactor: Code refactoring
- test: Adding tests
- docs: Documentation
- chore: Maintenance

Scopes (bounded contexts):
- catalog
- identity
- shopping
- orders
- payment
- shipping
- promotion
- shared

Examples:
feat(catalog): add product discount feature
fix(orders): correct tax calculation
refactor(shopping): simplify cart item logic
test(payment): add payment processing tests
docs(architecture): update context map
```

## Coding Standards

### Package Structure

```
Always follow this structure for each bounded context:

com.shopnow.<context>/
├── domain/
│   ├── model/           # Aggregates, entities, value objects
│   ├── repository/      # Repository interfaces (ports)
│   ├── event/           # Domain events
│   └── service/         # Domain services
├── application/
│   ├── command/         # Commands and handlers
│   ├── query/           # Queries and handlers
│   └── event/           # Event handlers
└── infrastructure/
    ├── adapter/
    │   ├── input/       # Controllers, listeners
    │   └── output/      # Repository implementations
    └── config/          # Configuration
```

### Naming Conventions

```kotlin
// Aggregates - Nouns
class Product
class Order
class User

// Value Objects - Descriptive nouns
data class Money(val amount: BigDecimal, val currency: Currency)
data class ProductName(val value: String)

// Commands - Imperative verbs
data class CreateProductCommand
data class UpdateProductPriceCommand

// Events - Past tense
data class ProductCreated
data class PriceChanged

// Handlers - <Command>Handler or <Query>Handler
class CreateProductHandler
class GetProductHandler

// Use Cases - <Verb><Noun>UseCase
interface CreateProductUseCase
interface GetProductUseCase

// DTOs - <Entity>DTO
data class ProductDTO
data class OrderDTO
```

### Domain Layer Rules

```kotlin
// ✅ GOOD - Pure domain logic
class Product(
    val id: ProductId,
    var price: Money
) {
    fun changePrice(newPrice: Money) {
        require(newPrice.isPositive()) { "Price must be positive" }
        this.price = newPrice
    }
}

// ❌ BAD - Framework dependencies in domain
class Product(
    @Id val id: UUID,           // JPA annotation - NO!
    @Column val price: BigDecimal  // JPA annotation - NO!
)
```

### Value Objects

```kotlin
// Always use value objects instead of primitives

// ❌ BAD
data class Product(
    val name: String,
    val price: BigDecimal
)

// ✅ GOOD
data class Product(
    val name: ProductName,
    val price: Money
)

@JvmInline
value class ProductName(val value: String) {
    init {
        require(value.isNotBlank()) { "Name cannot be blank" }
        require(value.length <= 150) { "Name too long" }
    }
}
```

### Async/Reactive Code

```kotlin
// Use suspend functions for async operations
suspend fun createProduct(command: CreateProductCommand): ProductId {
    val product = Product.create(...)
    productRepository.save(product)  // suspend function
    return product.id
}

// Use Flow for streaming
fun getAllProducts(): Flow<Product> {
    return productRepository.findAll()  // Returns Flow
}

// Use Mono/Flux in infrastructure layer
class ProductRepositoryAdapter(
    private val r2dbcRepository: ProductR2dbcRepository
) : ProductRepository {
    override suspend fun save(product: Product): Product {
        val entity = mapper.toEntity(product)
        val saved = r2dbcRepository.save(entity)  // Returns Mono
        return mapper.toDomain(saved)
    }
}
```

## Common Tasks

### Adding a New Bounded Context

1. Create package structure:
```
contexts/mycontext/
├── domain/
├── application/
└── infrastructure/
```

2. Create schema migration:
```sql
-- db/migration/mycontext/V1__mycontext__create_schema.sql
CREATE SCHEMA mycontext;
```

3. Create configuration:
```kotlin
@Configuration
class MyContextConfiguration {
    // Bean definitions
}
```

4. Update documentation:
- Add to BOUNDED_CONTEXTS.md
- Update context map in PRD.md

### Adding a New Aggregate

1. Create domain model:
```kotlin
// domain/model/MyAggregate.kt
class MyAggregate private constructor(
    val id: MyAggregateId,
    // properties
) {
    companion object {
        fun create(...): MyAggregate {
            // Creation logic
        }
    }

    // Behavior methods
}
```

2. Create repository interface:
```kotlin
// domain/repository/MyAggregateRepository.kt
interface MyAggregateRepository {
    suspend fun save(aggregate: MyAggregate): MyAggregate
    suspend fun findById(id: MyAggregateId): MyAggregate?
}
```

3. Implement repository:
```kotlin
// infrastructure/adapter/output/persistence/MyAggregateRepositoryAdapter.kt
class MyAggregateRepositoryAdapter : MyAggregateRepository {
    // Implementation
}
```

### Adding a New API Endpoint

1. Create request/response DTOs:
```kotlin
data class MyRequest(
    @field:NotBlank val field: String
)

data class MyResponse(val id: String)
```

2. Add to controller:
```kotlin
@PostMapping("/my-endpoint")
suspend fun myEndpoint(@RequestBody @Valid request: MyRequest): ResponseEntity<MyResponse> {
    // Delegate to use case
}
```

3. Update API documentation (OpenAPI annotations if needed)

### Running Tests

```bash
# All tests
./gradlew test

# Specific context
./gradlew :contexts:catalog:test

# Integration tests only
./gradlew integrationTest

# With coverage
./gradlew test jacocoTestReport
```

### Database Operations

```bash
# Run migrations
./gradlew flywayMigrate

# Check migration status
./gradlew flywayInfo

# Rollback (careful!)
./gradlew flywayUndo

# Connect to database
docker-compose exec postgres psql -U shopnow -d shopnow

# List schemas
\dn

# List tables in schema
\dt catalog.*

# View table structure
\d catalog.products
```

## Troubleshooting

### Application Won't Start

```bash
# Check if ports are in use
lsof -i :8080
lsof -i :5432
lsof -i :6379

# Check Docker containers
docker-compose ps
docker-compose logs postgres
docker-compose logs redis

# Clear Gradle cache
./gradlew clean

# Restart Docker
docker-compose down -v
docker-compose up -d
```

### Database Issues

```bash
# Reset database (WARNING: Deletes all data!)
docker-compose down -v
docker-compose up -d postgres
./gradlew flywayMigrate

# Check connection
docker-compose exec postgres psql -U shopnow -c "SELECT 1"
```

### Test Failures

```bash
# Run tests with more verbose output
./gradlew test --info

# Run single test
./gradlew test --tests "ProductTest.should create product"

# Debug tests in IntelliJ
# Right-click on test → Debug
```

### Migration Errors

```bash
# Check migration status
./gradlew flywayInfo

# Repair checksum
./gradlew flywayRepair

# Manual fix
docker-compose exec postgres psql -U shopnow
# Fix issue
./gradlew flywayMigrate
```

## Resources

### Documentation
- [PRD.md](PRD.md) - Product requirements
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture overview
- [HEXAGONAL_ARCHITECTURE.md](HEXAGONAL_ARCHITECTURE.md) - Hexagonal architecture guide
- [DDD_GUIDE.md](DDD_GUIDE.md) - DDD patterns and practices
- [BOUNDED_CONTEXTS.md](BOUNDED_CONTEXTS.md) - Bounded context details

### External Resources

**Domain-Driven Design:**
- Book: "Domain-Driven Design" by Eric Evans
- Book: "Implementing Domain-Driven Design" by Vaughn Vernon
- https://martinfowler.com/tags/domain%20driven%20design.html

**Hexagonal Architecture:**
- https://alistair.cockburn.us/hexagonal-architecture/
- https://netflixtechblog.com/ready-for-changes-with-hexagonal-architecture-b315ec967749

**Kotlin & Spring:**
- https://kotlinlang.org/docs/home.html
- https://spring.io/guides/tutorials/spring-boot-kotlin/
- https://docs.spring.io/spring-framework/reference/web/webflux.html

**Reactive Programming:**
- https://projectreactor.io/docs/core/release/reference/
- https://kotlin.github.io/kotlinx.coroutines/

### Getting Help

- **Team Chat**: [Slack/Teams channel]
- **Code Reviews**: Create PR and request review
- **Architecture Decisions**: Discuss in architecture channel
- **Questions**: Don't hesitate to ask!

## Next Steps

Now that you're set up:

1. ✅ Read the architecture documentation
2. ✅ Explore the codebase
3. ✅ Pick a small task from the backlog
4. ✅ Write your first feature
5. ✅ Get code reviewed
6. ✅ Deploy to staging

Welcome to the team! 🚀

---

**Version**: 1.0
**Last Updated**: 2025-11-29
