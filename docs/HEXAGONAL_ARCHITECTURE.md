# Hexagonal Architecture Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Core Concepts](#core-concepts)
3. [Layers & Responsibilities](#layers--responsibilities)
4. [Ports & Adapters](#ports--adapters)
5. [Implementation Guidelines](#implementation-guidelines)
6. [Code Examples](#code-examples)
7. [Best Practices](#best-practices)
8. [Common Pitfalls](#common-pitfalls)

## Introduction

### What is Hexagonal Architecture?

Hexagonal Architecture (also known as Ports and Adapters) is an architectural pattern that aims to create loosely coupled application components that can be easily connected to their software environment through ports and adapters.

**Key Goals**:
- **Testability**: Core business logic can be tested without external dependencies
- **Flexibility**: Easy to swap implementations (databases, frameworks, etc.)
- **Maintainability**: Clear separation of concerns
- **Independence**: Domain logic is independent of infrastructure

### Why Hexagonal Architecture for ShopNow?

1. **Multiple delivery mechanisms**: REST, GraphQL, events, CLI
2. **Multiple data sources**: PostgreSQL (sync/async), Redis, external APIs
3. **Testing complexity**: Need to test business logic independently
4. **Future growth**: Easy to add new integrations without affecting core logic

## Core Concepts

### The Hexagon

```
                    ┌─────────────────────────────────────┐
                    │         External World              │
                    │  (HTTP, DB, Message Queue, etc.)    │
                    └───────────┬─────────────────────────┘
                                │
                    ┌───────────▼─────────────────────────┐
                    │         Adapters Layer              │
                    │    (Input & Output Adapters)        │
                    │                                     │
                    │  ┌────────────┐  ┌────────────┐    │
                    │  │   REST     │  │  Database  │    │
                    │  │  Adapter   │  │  Adapter   │    │
                    │  └─────┬──────┘  └──────┬─────┘    │
                    └────────┼────────────────┼───────────┘
                             │                │
                    ┌────────▼────────────────▼───────────┐
                    │          Ports Layer                │
                    │      (Interfaces/Contracts)         │
                    │                                     │
                    │  ┌────────────┐  ┌────────────┐    │
                    │  │  Input     │  │  Output    │    │
                    │  │   Ports    │  │   Ports    │    │
                    │  └─────┬──────┘  └──────┬─────┘    │
                    └────────┼────────────────┼───────────┘
                             │                │
                    ┌────────▼────────────────▼───────────┐
                    │        Application Layer            │
                    │         (Use Cases)                 │
                    │                                     │
                    │  Command & Query Handlers           │
                    │  Orchestration Logic                │
                    └────────────┬────────────────────────┘
                                 │
                    ┌────────────▼────────────────────────┐
                    │         Domain Layer                │
                    │      (Business Logic)               │
                    │                                     │
                    │  Aggregates, Entities,              │
                    │  Value Objects, Domain Events       │
                    │  Domain Services                    │
                    └─────────────────────────────────────┘
```

### Dependency Rule

**Dependencies point inward**:
- Domain knows nothing about outer layers
- Application knows Domain but not Infrastructure
- Infrastructure knows everything (it implements the contracts)

```
Infrastructure → Application → Domain
    (depends on)    (depends on)
```

## Layers & Responsibilities

### 1. Domain Layer (Core/Center)

**Purpose**: Contains pure business logic, independent of frameworks and external concerns.

**Components**:
- **Aggregates**: Cluster of entities and value objects with a root entity
- **Entities**: Objects with identity
- **Value Objects**: Immutable objects defined by their attributes
- **Domain Events**: Things that happened in the domain
- **Domain Services**: Business logic that doesn't belong to a single entity
- **Repository Interfaces**: Contracts for data access (OUTPUT PORTS)

**Rules**:
- NO framework dependencies (no Spring, no JPA annotations)
- NO infrastructure concerns (no database, no HTTP)
- Pure Kotlin/Java classes
- Rich domain models with behavior

**Example Structure**:
```
domain/
├── model/
│   ├── Product.kt              # Aggregate Root
│   ├── ProductId.kt            # Value Object
│   ├── Money.kt                # Value Object
│   └── Category.kt             # Entity
├── repository/
│   └── ProductRepository.kt    # Port (interface)
├── event/
│   ├── ProductCreated.kt
│   └── PriceChanged.kt
└── service/
    └── PricingService.kt       # Domain Service
```

### 2. Application Layer

**Purpose**: Orchestrates domain objects to fulfill use cases. Contains application-specific business rules.

**Components**:
- **Commands**: Requests to change state
- **Queries**: Requests to read state
- **Command Handlers**: Execute commands
- **Query Handlers**: Execute queries
- **DTOs**: Data transfer objects for input/output
- **Use Case Interfaces**: INPUT PORTS

**Rules**:
- Orchestrates domain objects
- Transaction boundaries
- NO UI/API logic
- NO infrastructure details
- Can use framework annotations for DI

**Example Structure**:
```
application/
├── command/
│   ├── CreateProductCommand.kt
│   ├── CreateProductHandler.kt
│   ├── UpdatePriceCommand.kt
│   └── UpdatePriceHandler.kt
├── query/
│   ├── GetProductQuery.kt
│   ├── GetProductHandler.kt
│   └── ProductDTO.kt
└── port/
    ├── input/
    │   └── ProductUseCase.kt       # Input Port
    └── output/
        ├── ProductRepository.kt     # Output Port
        └── EventPublisher.kt        # Output Port
```

### 3. Infrastructure Layer (Outside)

**Purpose**: Implements the interfaces defined by domain/application. Handles all technical details.

**Components**:
- **Input Adapters**: Receive requests from outside (Controllers, Event Listeners)
- **Output Adapters**: Implement output ports (Repository implementations, Event publishers)
- **Configuration**: Spring configuration, dependency injection
- **Mappers**: Convert between domain models and persistence models

**Rules**:
- Implements ports (interfaces)
- Can use any framework/library
- Isolated from domain logic

**Example Structure**:
```
infrastructure/
├── adapter/
│   ├── input/
│   │   ├── rest/
│   │   │   ├── ProductController.kt
│   │   │   └── ProductRequest.kt
│   │   └── event/
│   │       └── OrderEventListener.kt
│   └── output/
│       ├── persistence/
│       │   ├── jpa/
│       │   │   ├── ProductEntity.kt
│       │   │   ├── ProductJpaRepository.kt
│       │   │   └── ProductRepositoryAdapter.kt
│       │   └── r2dbc/
│       │       └── ProductR2dbcRepository.kt
│       └── messaging/
│           └── KafkaEventPublisher.kt
└── config/
    ├── DatabaseConfig.kt
    └── WebConfig.kt
```

## Ports & Adapters

### Input Ports (Driving/Primary)

**Definition**: Interfaces that define how the application can be used.

**Examples**:
- Use Case interfaces
- API contracts
- Command/Query interfaces

```kotlin
// Input Port - defines WHAT the application can do
interface CreateProductUseCase {
    suspend fun execute(command: CreateProductCommand): ProductId
}

// Input Adapter - REST Controller
@RestController
class ProductController(
    private val createProduct: CreateProductUseCase
) {
    @PostMapping("/api/products")
    suspend fun create(@RequestBody request: CreateProductRequest): ResponseEntity<ProductResponse> {
        val command = request.toCommand()
        val productId = createProduct.execute(command)
        return ResponseEntity.created(...)
    }
}
```

### Output Ports (Driven/Secondary)

**Definition**: Interfaces that define what the application needs from external systems.

**Examples**:
- Repository interfaces
- Event publisher interfaces
- External service interfaces

```kotlin
// Output Port - defines WHAT the application needs
interface ProductRepository {
    suspend fun save(product: Product): Product
    suspend fun findById(id: ProductId): Product?
    fun findAll(): Flow<Product>
}

// Output Adapter - implements HOW to fulfill the need
class ProductRepositoryAdapter(
    private val r2dbcRepository: ProductR2dbcRepository,
    private val mapper: ProductMapper
) : ProductRepository {
    override suspend fun save(product: Product): Product {
        val entity = mapper.toEntity(product)
        val saved = r2dbcRepository.save(entity)
        return mapper.toDomain(saved)
    }
    // ...
}
```

## Implementation Guidelines

### Dependency Injection Flow

```
┌──────────────────────────────────────────────────────┐
│                   Spring Context                     │
│                                                       │
│  ┌────────────────────────────────────────────────┐ │
│  │  ProductController (Input Adapter)             │ │
│  │  - Depends on: CreateProductUseCase (Port)     │ │
│  └────────────────────┬───────────────────────────┘ │
│                       │                              │
│  ┌────────────────────▼───────────────────────────┐ │
│  │  CreateProductHandler (Application)            │ │
│  │  - Implements: CreateProductUseCase            │ │
│  │  - Depends on: ProductRepository (Port)        │ │
│  └────────────────────┬───────────────────────────┘ │
│                       │                              │
│  ┌────────────────────▼───────────────────────────┐ │
│  │  ProductRepositoryAdapter (Output Adapter)     │ │
│  │  - Implements: ProductRepository               │ │
│  └────────────────────────────────────────────────┘ │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### Configuration Example

```kotlin
@Configuration
class CatalogConfiguration {

    // Output Adapter (Repository Implementation)
    @Bean
    fun productRepository(
        r2dbcRepository: ProductR2dbcRepository,
        mapper: ProductMapper
    ): ProductRepository {
        return ProductRepositoryAdapter(r2dbcRepository, mapper)
    }

    // Application Service (Use Case Implementation)
    @Bean
    fun createProductUseCase(
        repository: ProductRepository,
        eventPublisher: EventPublisher
    ): CreateProductUseCase {
        return CreateProductHandler(repository, eventPublisher)
    }
}
```

## Code Examples

### Complete Flow Example

#### 1. Domain Layer

```kotlin
// domain/model/Product.kt
class Product private constructor(
    val id: ProductId,
    var name: ProductName,
    var price: Money,
    var stock: Stock,
    val events: MutableList<DomainEvent> = mutableListOf()
) {
    companion object {
        fun create(
            id: ProductId,
            name: ProductName,
            price: Money,
            initialStock: Stock
        ): Product {
            require(price.amount > BigDecimal.ZERO) { "Price must be positive" }

            return Product(id, name, price, initialStock).apply {
                addEvent(ProductCreated(id, name, price))
            }
        }
    }

    fun changePrice(newPrice: Money) {
        require(newPrice.amount > BigDecimal.ZERO) { "Price must be positive" }

        val oldPrice = this.price
        this.price = newPrice
        addEvent(PriceChanged(id, oldPrice, newPrice))
    }

    private fun addEvent(event: DomainEvent) {
        events.add(event)
    }
}

// domain/model/ProductId.kt (Value Object)
@JvmInline
value class ProductId(val value: UUID) {
    companion object {
        fun generate() = ProductId(UUID.randomUUID())
    }
}

// domain/model/Money.kt (Value Object)
data class Money(
    val amount: BigDecimal,
    val currency: Currency = Currency.getInstance("USD")
) {
    init {
        require(amount.scale() <= 2) { "Money cannot have more than 2 decimal places" }
    }

    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "Cannot add different currencies" }
        return Money(amount + other.amount, currency)
    }
}

// domain/repository/ProductRepository.kt (Output Port)
interface ProductRepository {
    suspend fun save(product: Product): Product
    suspend fun findById(id: ProductId): Product?
    fun findAll(): Flow<Product>
}

// domain/event/ProductCreated.kt
data class ProductCreated(
    val productId: ProductId,
    val name: ProductName,
    val price: Money,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent
```

#### 2. Application Layer

```kotlin
// application/command/CreateProductCommand.kt
data class CreateProductCommand(
    val name: String,
    val description: String,
    val price: BigDecimal,
    val currency: String,
    val initialStock: Int
)

// application/command/CreateProductHandler.kt
@Service
class CreateProductHandler(
    private val productRepository: ProductRepository,
    private val eventPublisher: EventPublisher
) : CreateProductUseCase {

    @Transactional
    override suspend fun execute(command: CreateProductCommand): ProductId {
        // Create domain objects
        val productId = ProductId.generate()
        val name = ProductName(command.name)
        val price = Money(command.price, Currency.getInstance(command.currency))
        val stock = Stock(command.initialStock)

        // Business logic in domain
        val product = Product.create(productId, name, price, stock)

        // Persist
        productRepository.save(product)

        // Publish events
        product.events.forEach { eventPublisher.publish(it) }

        return productId
    }
}

// application/port/input/CreateProductUseCase.kt (Input Port)
interface CreateProductUseCase {
    suspend fun execute(command: CreateProductCommand): ProductId
}

// application/query/GetProductQuery.kt
data class GetProductQuery(val productId: String)

// application/query/ProductDTO.kt
data class ProductDTO(
    val id: String,
    val name: String,
    val price: BigDecimal,
    val currency: String,
    val stock: Int
)

// application/query/GetProductHandler.kt
@Service
class GetProductHandler(
    private val productRepository: ProductRepository
) : GetProductUseCase {

    override suspend fun execute(query: GetProductQuery): ProductDTO? {
        val productId = ProductId(UUID.fromString(query.productId))
        val product = productRepository.findById(productId) ?: return null

        return ProductDTO(
            id = product.id.value.toString(),
            name = product.name.value,
            price = product.price.amount,
            currency = product.price.currency.currencyCode,
            stock = product.stock.quantity
        )
    }
}
```

#### 3. Infrastructure Layer

```kotlin
// infrastructure/adapter/input/rest/ProductController.kt
@RestController
@RequestMapping("/api/products")
class ProductController(
    private val createProduct: CreateProductUseCase,
    private val getProduct: GetProductUseCase
) {

    @PostMapping
    suspend fun create(@RequestBody @Valid request: CreateProductRequest): ResponseEntity<ProductResponse> {
        val command = request.toCommand()
        val productId = createProduct.execute(command)

        return ResponseEntity.created(URI.create("/api/products/${productId.value}"))
            .body(ProductResponse(productId.value.toString()))
    }

    @GetMapping("/{id}")
    suspend fun getById(@PathVariable id: String): ResponseEntity<ProductDTO> {
        val query = GetProductQuery(id)
        val product = getProduct.execute(query) ?: return ResponseEntity.notFound().build()

        return ResponseEntity.ok(product)
    }
}

// infrastructure/adapter/input/rest/CreateProductRequest.kt
data class CreateProductRequest(
    @field:NotBlank val name: String,
    @field:NotBlank val description: String,
    @field:Positive val price: BigDecimal,
    val currency: String = "USD",
    @field:PositiveOrZero val initialStock: Int
) {
    fun toCommand() = CreateProductCommand(
        name = name,
        description = description,
        price = price,
        currency = currency,
        initialStock = initialStock
    )
}

// infrastructure/adapter/output/persistence/ProductEntity.kt
@Table("products", schema = "catalog")
data class ProductEntity(
    @Id val id: UUID,
    val name: String,
    val description: String,
    val price: BigDecimal,
    val currency: String,
    val stock: Int,
    val createdAt: Instant,
    val updatedAt: Instant
)

// infrastructure/adapter/output/persistence/ProductMapper.kt
@Component
class ProductMapper {
    fun toDomain(entity: ProductEntity): Product {
        // Reconstitute domain object from entity
        // Note: Using reflection or factory method to bypass domain validation
        return Product(
            id = ProductId(entity.id),
            name = ProductName(entity.name),
            price = Money(entity.price, Currency.getInstance(entity.currency)),
            stock = Stock(entity.stock)
        )
    }

    fun toEntity(product: Product): ProductEntity {
        return ProductEntity(
            id = product.id.value,
            name = product.name.value,
            price = product.price.amount,
            currency = product.price.currency.currencyCode,
            stock = product.stock.quantity,
            createdAt = Instant.now(),
            updatedAt = Instant.now()
        )
    }
}

// infrastructure/adapter/output/persistence/ProductRepositoryAdapter.kt
@Repository
class ProductRepositoryAdapter(
    private val r2dbcRepository: ProductR2dbcRepository,
    private val mapper: ProductMapper
) : ProductRepository {

    override suspend fun save(product: Product): Product {
        val entity = mapper.toEntity(product)
        val saved = r2dbcRepository.save(entity)
        return mapper.toDomain(saved)
    }

    override suspend fun findById(id: ProductId): Product? {
        return r2dbcRepository.findById(id.value)?.let { mapper.toDomain(it) }
    }

    override fun findAll(): Flow<Product> {
        return r2dbcRepository.findAll().map { mapper.toDomain(it) }
    }
}

// infrastructure/adapter/output/persistence/ProductR2dbcRepository.kt
@Repository
interface ProductR2dbcRepository : R2dbcRepository<ProductEntity, UUID>
```

## Best Practices

### 1. Keep Domain Pure

```kotlin
// ❌ BAD - Domain depends on infrastructure
class Product(
    @Id val id: UUID,  // JPA annotation
    val name: String
)

// ✅ GOOD - Pure domain
class Product(
    val id: ProductId,
    val name: ProductName
)
```

### 2. Use Value Objects

```kotlin
// ❌ BAD - Primitive obsession
data class Product(
    val name: String,
    val price: BigDecimal
)

// ✅ GOOD - Rich domain model
data class Product(
    val name: ProductName,
    val price: Money
)
```

### 3. Ports are Interfaces in Domain/Application

```kotlin
// ✅ GOOD - Port defined in domain
// domain/repository/ProductRepository.kt
interface ProductRepository {
    suspend fun save(product: Product): Product
}

// ✅ GOOD - Adapter implements port
// infrastructure/adapter/output/persistence/ProductRepositoryAdapter.kt
class ProductRepositoryAdapter(...) : ProductRepository {
    override suspend fun save(product: Product): Product { ... }
}
```

### 4. Dependencies Point Inward

```kotlin
// ✅ GOOD - Application depends on domain
class CreateProductHandler(
    private val repository: ProductRepository  // Domain interface
)

// ❌ BAD - Domain depends on infrastructure
class Product(
    private val repository: SomeJpaRepository  // Infrastructure class
)
```

### 5. Use Mappers Between Layers

```kotlin
// ✅ GOOD - Separate domain and persistence models
class ProductMapper {
    fun toDomain(entity: ProductEntity): Product { ... }
    fun toEntity(product: Product): ProductEntity { ... }
}

// ❌ BAD - Mixing domain and persistence
@Entity  // JPA annotation on domain
class Product { ... }
```

## Common Pitfalls

### 1. Anemic Domain Model

```kotlin
// ❌ BAD - No behavior, just getters/setters
class Product {
    var price: BigDecimal = BigDecimal.ZERO
}

// Application service has business logic
class ProductService {
    fun changePrice(product: Product, newPrice: BigDecimal) {
        if (newPrice <= BigDecimal.ZERO) throw Exception("Invalid price")
        product.price = newPrice
    }
}

// ✅ GOOD - Rich domain model
class Product {
    private var _price: Money

    fun changePrice(newPrice: Money) {
        require(newPrice.amount > BigDecimal.ZERO) { "Price must be positive" }
        _price = newPrice
    }
}
```

### 2. Breaking the Dependency Rule

```kotlin
// ❌ BAD - Domain imports infrastructure
import org.springframework.data.jpa.repository.JpaRepository

interface ProductRepository : JpaRepository<Product, UUID>

// ✅ GOOD - Domain defines its own contracts
interface ProductRepository {
    suspend fun save(product: Product): Product
}
```

### 3. Fat Controllers

```kotlin
// ❌ BAD - Business logic in controller
@PostMapping
fun create(@RequestBody request: CreateProductRequest): ResponseEntity<*> {
    // Validation
    if (request.price <= BigDecimal.ZERO) return ResponseEntity.badRequest()

    // Business logic
    val product = Product(...)
    repository.save(product)

    // More logic...
    return ResponseEntity.ok()
}

// ✅ GOOD - Controller delegates to use case
@PostMapping
suspend fun create(@RequestBody @Valid request: CreateProductRequest): ResponseEntity<*> {
    val command = request.toCommand()
    val productId = createProduct.execute(command)
    return ResponseEntity.created(...)
}
```

### 4. Leaking Infrastructure Details

```kotlin
// ❌ BAD - Returning JPA entity from use case
interface GetProductUseCase {
    suspend fun execute(id: UUID): ProductEntity
}

// ✅ GOOD - Returning DTO
interface GetProductUseCase {
    suspend fun execute(query: GetProductQuery): ProductDTO?
}
```

## Testing Strategy

### Domain Layer (Unit Tests)

```kotlin
class ProductTest {
    @Test
    fun `should create product with valid data`() {
        val product = Product.create(
            id = ProductId.generate(),
            name = ProductName("Laptop"),
            price = Money(BigDecimal("999.99")),
            stock = Stock(10)
        )

        assertThat(product.name.value).isEqualTo("Laptop")
        assertThat(product.events).hasSize(1)
        assertThat(product.events.first()).isInstanceOf<ProductCreated>()
    }

    @Test
    fun `should not create product with negative price`() {
        assertThrows<IllegalArgumentException> {
            Product.create(
                id = ProductId.generate(),
                name = ProductName("Laptop"),
                price = Money(BigDecimal("-100")),
                stock = Stock(10)
            )
        }
    }
}
```

### Application Layer (Integration Tests)

```kotlin
class CreateProductHandlerTest {
    private val mockRepository = mockk<ProductRepository>()
    private val mockEventPublisher = mockk<EventPublisher>()
    private val handler = CreateProductHandler(mockRepository, mockEventPublisher)

    @Test
    fun `should create product and publish event`() = runBlocking {
        // Given
        val command = CreateProductCommand(
            name = "Laptop",
            description = "Gaming laptop",
            price = BigDecimal("999.99"),
            currency = "USD",
            initialStock = 10
        )

        coEvery { mockRepository.save(any()) } returns mockk()
        every { mockEventPublisher.publish(any()) } just Runs

        // When
        val productId = handler.execute(command)

        // Then
        assertThat(productId).isNotNull()
        coVerify { mockRepository.save(any()) }
        verify { mockEventPublisher.publish(any<ProductCreated>()) }
    }
}
```

### Infrastructure Layer (Integration Tests with Testcontainers)

```kotlin
@SpringBootTest
@Testcontainers
class ProductRepositoryAdapterTest {

    @Container
    val postgres = PostgreSQLContainer("postgres:17")

    @Autowired
    lateinit var repository: ProductRepository

    @Test
    fun `should save and retrieve product`() = runBlocking {
        // Given
        val product = Product.create(...)

        // When
        repository.save(product)
        val retrieved = repository.findById(product.id)

        // Then
        assertThat(retrieved).isNotNull()
        assertThat(retrieved?.name).isEqualTo(product.name)
    }
}
```

## Summary

Hexagonal Architecture provides:
- Clear separation of concerns
- Testable business logic
- Flexibility to change infrastructure
- Protection from framework lock-in

Key principles:
1. Domain is the center and knows nothing about the outside
2. Ports define contracts (interfaces)
3. Adapters implement contracts
4. Dependencies point inward
5. Use mappers between layers

Remember: The goal is to protect business logic and make it easy to change everything else!

---

**Version**: 1.0
**Last Updated**: 2025-11-29
