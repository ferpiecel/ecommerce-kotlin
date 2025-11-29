# Domain-Driven Design (DDD) Guide

## Table of Contents
1. [Introduction](#introduction)
2. [Strategic Design](#strategic-design)
3. [Tactical Design](#tactical-design)
4. [Building Blocks](#building-blocks)
5. [Implementation Examples](#implementation-examples)
6. [Best Practices](#best-practices)

## Introduction

### What is Domain-Driven Design?

Domain-Driven Design (DDD) is an approach to software development that focuses on modeling the business domain and using that model to drive the software design.

**Core Principles**:
- **Ubiquitous Language**: Shared language between developers and domain experts
- **Bounded Contexts**: Explicit boundaries within which a model is defined
- **Domain Model**: Rich representation of business concepts
- **Strategic Design**: High-level structure and organization
- **Tactical Design**: Low-level implementation patterns

### Why DDD for ShopNow?

E-commerce is a complex domain with:
- Multiple subdomains (catalog, orders, payments, shipping)
- Complex business rules
- Different stakeholders with different concerns
- Need for scalability and evolution

## Strategic Design

### Bounded Contexts

A Bounded Context is an explicit boundary within which a domain model is defined and applicable.

#### ShopNow Bounded Contexts

```
┌─────────────────────────────────────────────────────────┐
│                     ShopNow System                       │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Catalog    │  │  Identity &  │  │   Shopping   │ │
│  │   Context    │  │Access Context│  │   Context    │ │
│  │              │  │              │  │              │ │
│  │ - Products   │  │ - Users      │  │ - Cart       │ │
│  │ - Categories │  │ - Auth       │  │ - Wishlist   │ │
│  │ - Inventory  │  │ - Roles      │  │ - Reviews    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │    Order     │  │   Payment    │  │   Shipping   │ │
│  │   Context    │  │   Context    │  │   Context    │ │
│  │              │  │              │  │              │ │
│  │ - Orders     │  │ - Payments   │  │ - Addresses  │ │
│  │ - OrderItems │  │ - Methods    │  │ - Shipping   │ │
│  │ - Returns    │  │ - Refunds    │  │ - Tracking   │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Promotion   │  │   Partner    │  │Notification  │ │
│  │   Context    │  │   Context    │  │   Context    │ │
│  │              │  │              │  │              │ │
│  │ - Discounts  │  │ - Affiliates │  │ - Alerts     │ │
│  │ - Coupons    │  │ - Suppliers  │  │ - Messages   │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Context Mapping

Defines relationships between bounded contexts.

#### Relationship Types

1. **Shared Kernel**: Common code shared between contexts (use sparingly)
2. **Customer-Supplier**: Upstream context provides service to downstream
3. **Conformist**: Downstream conforms to upstream model
4. **Anti-Corruption Layer (ACL)**: Translation layer to protect domain model
5. **Partnership**: Two contexts collaborate closely
6. **Published Language**: Well-documented shared language

#### ShopNow Context Map

```
┌──────────────┐
│   Catalog    │
│   Context    │◄─────────┐
└──────┬───────┘          │
       │                  │
       │ (Events)         │ (ACL)
       │                  │
       ▼                  │
┌──────────────┐    ┌─────┴──────┐
│    Order     │───▶│  Shipping  │
│   Context    │    │  Context   │
└──────┬───────┘    └────────────┘
       │
       │ (Events)
       │
       ▼
┌──────────────┐
│   Payment    │
│   Context    │
└──────────────┘
```

### Ubiquitous Language

Each bounded context has its own ubiquitous language.

#### Example: Product in Different Contexts

**Catalog Context**:
- Product: SKU, name, description, price, stock
- Focus: Product information and availability

**Order Context**:
- OrderLine: Product reference, quantity, unit price at time of order
- Focus: What was ordered and at what price

**Shipping Context**:
- ShippableItem: Product reference, weight, dimensions
- Focus: Physical characteristics for shipping

**Key Point**: The same business concept may be modeled differently in different contexts!

## Tactical Design

### Building Blocks

```
┌─────────────────────────────────────────────────────┐
│              Tactical Patterns                       │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────────┐  │
│  │            Aggregate                         │  │
│  │  ┌────────────────────────────────────────┐ │  │
│  │  │        Aggregate Root (Entity)         │ │  │
│  │  │  ┌─────────┐  ┌─────────┐             │ │  │
│  │  │  │ Entity  │  │ Value   │             │ │  │
│  │  │  │         │  │ Object  │             │ │  │
│  │  │  └─────────┘  └─────────┘             │ │  │
│  │  └────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────┘  │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐                │
│  │   Domain     │  │  Repository  │                 │
│  │   Service    │  │  (Interface) │                 │
│  └──────────────┘  └──────────────┘                │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐                │
│  │   Domain     │  │  Factory     │                 │
│  │   Event      │  │              │                 │
│  └──────────────┘  └──────────────┘                │
│                                                      │
└─────────────────────────────────────────────────────┘
```

## Building Blocks

### 1. Entities

Objects with a unique identity that persists over time.

**Characteristics**:
- Has a unique identifier
- Identity matters more than attributes
- Mutable
- Continuity through lifecycle

```kotlin
// Entity - defined by identity
class Order(
    val id: OrderId,                    // Identity
    val customerId: CustomerId,
    var status: OrderStatus,            // Mutable state
    var total: Money,
    private val items: MutableList<OrderItem> = mutableListOf()
) {
    // Behavior
    fun addItem(item: OrderItem) {
        items.add(item)
        recalculateTotal()
    }

    fun confirm() {
        require(status == OrderStatus.PENDING) { "Only pending orders can be confirmed" }
        status = OrderStatus.CONFIRMED
    }

    private fun recalculateTotal() {
        total = items.fold(Money.ZERO) { acc, item -> acc + item.subtotal }
    }

    // Two orders are equal if they have the same ID
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Order) return false
        return id == other.id
    }

    override fun hashCode(): Int = id.hashCode()
}
```

### 2. Value Objects

Objects defined by their attributes, with no identity.

**Characteristics**:
- No identity
- Immutable
- Defined by attributes
- Replaceable
- Can contain business logic

```kotlin
// Value Object - defined by attributes
data class Money(
    val amount: BigDecimal,
    val currency: Currency
) {
    companion object {
        val ZERO = Money(BigDecimal.ZERO, Currency.getInstance("USD"))
    }

    init {
        require(amount.scale() <= 2) { "Money cannot have more than 2 decimal places" }
    }

    // Business logic
    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "Cannot add different currencies" }
        return Money(amount + other.amount, currency)
    }

    operator fun times(multiplier: Int): Money {
        return Money(amount * multiplier.toBigDecimal(), currency)
    }

    fun isPositive(): Boolean = amount > BigDecimal.ZERO
}

// Another example
data class Address(
    val street: String,
    val city: String,
    val state: String,
    val postalCode: PostalCode,
    val country: Country
) {
    init {
        require(street.isNotBlank()) { "Street cannot be blank" }
        require(city.isNotBlank()) { "City cannot be blank" }
    }

    fun formattedAddress(): String {
        return "$street\n$city, $state ${postalCode.value}\n${country.name}"
    }
}

// Inline value class for type safety
@JvmInline
value class PostalCode(val value: String) {
    init {
        require(value.matches(Regex("\\d{5}(-\\d{4})?"))) {
            "Invalid postal code format"
        }
    }
}
```

### 3. Aggregates

A cluster of domain objects treated as a single unit for data changes.

**Characteristics**:
- Has a root entity (Aggregate Root)
- Enforces invariants
- Transactional boundary
- References other aggregates by ID only
- Internal entities accessed through root

```kotlin
// Aggregate Root
class Order private constructor(
    val id: OrderId,
    val customerId: CustomerId,          // Reference to another aggregate
    var status: OrderStatus,
    private val _items: MutableList<OrderItem>,
    private val _events: MutableList<DomainEvent> = mutableListOf()
) {
    // Expose items as immutable
    val items: List<OrderItem> get() = _items.toList()
    val events: List<DomainEvent> get() = _events.toList()

    companion object {
        fun create(customerId: CustomerId): Order {
            val order = Order(
                id = OrderId.generate(),
                customerId = customerId,
                status = OrderStatus.DRAFT,
                _items = mutableListOf()
            )
            order.addEvent(OrderCreated(order.id, customerId))
            return order
        }
    }

    // Public API - only way to modify the aggregate
    fun addItem(productId: ProductId, quantity: Int, unitPrice: Money) {
        // Enforce invariants
        require(status == OrderStatus.DRAFT) { "Cannot add items to non-draft order" }
        require(quantity > 0) { "Quantity must be positive" }

        val existingItem = _items.find { it.productId == productId }
        if (existingItem != null) {
            existingItem.increaseQuantity(quantity)
        } else {
            val item = OrderItem.create(
                productId = productId,
                quantity = quantity,
                unitPrice = unitPrice
            )
            _items.add(item)
        }

        addEvent(OrderItemAdded(id, productId, quantity))
    }

    fun removeItem(productId: ProductId) {
        require(status == OrderStatus.DRAFT) { "Cannot remove items from non-draft order" }

        _items.removeIf { it.productId == productId }
        addEvent(OrderItemRemoved(id, productId))
    }

    fun confirm() {
        // Business rules
        require(status == OrderStatus.DRAFT) { "Only draft orders can be confirmed" }
        require(_items.isNotEmpty()) { "Cannot confirm empty order" }

        status = OrderStatus.CONFIRMED
        addEvent(OrderConfirmed(id, calculateTotal()))
    }

    fun calculateTotal(): Money {
        return _items.fold(Money.ZERO) { acc, item -> acc + item.subtotal() }
    }

    private fun addEvent(event: DomainEvent) {
        _events.add(event)
    }
}

// Entity inside aggregate (not an aggregate root)
class OrderItem internal constructor(
    val productId: ProductId,              // Reference by ID
    var quantity: Int,
    val unitPrice: Money
) {
    companion object {
        fun create(productId: ProductId, quantity: Int, unitPrice: Money): OrderItem {
            require(quantity > 0) { "Quantity must be positive" }
            require(unitPrice.isPositive()) { "Unit price must be positive" }

            return OrderItem(productId, quantity, unitPrice)
        }
    }

    fun increaseQuantity(amount: Int) {
        require(amount > 0) { "Amount must be positive" }
        quantity += amount
    }

    fun subtotal(): Money = unitPrice * quantity
}
```

### 4. Domain Services

Business logic that doesn't naturally fit in an entity or value object.

**When to use**:
- Operation involves multiple aggregates
- Stateless operation
- Business process that doesn't belong to a single entity

```kotlin
// Domain Service
class PricingService {

    fun calculateDiscountedPrice(
        basePrice: Money,
        discount: Discount,
        customer: Customer
    ): Money {
        var finalPrice = basePrice

        // Apply discount
        finalPrice = discount.apply(finalPrice)

        // Apply customer-specific pricing (e.g., VIP discount)
        if (customer.isVIP()) {
            finalPrice = finalPrice * BigDecimal("0.95") // 5% VIP discount
        }

        return finalPrice
    }

    fun canApplyDiscount(discount: Discount, product: Product): Boolean {
        // Business rules for discount applicability
        if (discount.isExpired()) return false
        if (!discount.isApplicableToCategory(product.categoryId)) return false
        if (product.price < discount.minimumPurchaseAmount) return false

        return true
    }
}

// Another example: Order fulfillment orchestration
class OrderFulfillmentService(
    private val inventoryService: InventoryService,
    private val paymentService: PaymentService
) {

    suspend fun fulfill(order: Order): FulfillmentResult {
        // Check inventory across multiple products
        val inventoryCheck = inventoryService.checkAvailability(
            order.items.map { it.productId to it.quantity }
        )

        if (!inventoryCheck.allAvailable) {
            return FulfillmentResult.InsufficientInventory(inventoryCheck.unavailableItems)
        }

        // Reserve inventory
        inventoryService.reserve(order.id, order.items)

        // Process payment
        val paymentResult = paymentService.process(order.id, order.calculateTotal())

        return when (paymentResult) {
            is PaymentResult.Success -> {
                inventoryService.commit(order.id)
                FulfillmentResult.Success
            }
            is PaymentResult.Failed -> {
                inventoryService.rollback(order.id)
                FulfillmentResult.PaymentFailed(paymentResult.reason)
            }
        }
    }
}
```

### 5. Domain Events

Something that happened in the domain that domain experts care about.

**Characteristics**:
- Immutable
- Past tense naming
- Contains relevant data
- Timestamp
- Can trigger side effects

```kotlin
// Base interface
interface DomainEvent {
    val occurredOn: Instant
    val eventId: UUID get() = UUID.randomUUID()
}

// Catalog Context Events
data class ProductCreated(
    val productId: ProductId,
    val name: String,
    val price: Money,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent

data class ProductPriceChanged(
    val productId: ProductId,
    val oldPrice: Money,
    val newPrice: Money,
    val changedBy: UserId,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent

data class ProductOutOfStock(
    val productId: ProductId,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent

// Order Context Events
data class OrderCreated(
    val orderId: OrderId,
    val customerId: CustomerId,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent

data class OrderConfirmed(
    val orderId: OrderId,
    val total: Money,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent

data class OrderShipped(
    val orderId: OrderId,
    val trackingNumber: String,
    override val occurredOn: Instant = Instant.now()
) : DomainEvent

// Usage in aggregate
class Product {
    private val _events: MutableList<DomainEvent> = mutableListOf()
    val events: List<DomainEvent> get() = _events.toList()

    fun changePrice(newPrice: Money, changedBy: UserId) {
        val oldPrice = this.price
        this.price = newPrice

        _events.add(ProductPriceChanged(id, oldPrice, newPrice, changedBy))
    }

    fun decreaseStock(quantity: Int) {
        stock -= quantity

        if (stock == 0) {
            _events.add(ProductOutOfStock(id))
        }
    }
}
```

### 6. Repositories

Abstraction for accessing aggregates.

**Characteristics**:
- Collection-like interface
- Works with aggregates, not entities
- Hides persistence details
- Defined in domain, implemented in infrastructure

```kotlin
// Repository interface (in domain layer)
interface OrderRepository {
    suspend fun save(order: Order): Order
    suspend fun findById(id: OrderId): Order?
    fun findByCustomerId(customerId: CustomerId): Flow<Order>
    suspend fun existsById(id: OrderId): Boolean
    suspend fun delete(order: Order)
}

// Usage in application service
class ConfirmOrderHandler(
    private val orderRepository: OrderRepository,
    private val eventPublisher: EventPublisher
) {
    suspend fun execute(command: ConfirmOrderCommand) {
        // Load aggregate
        val order = orderRepository.findById(command.orderId)
            ?: throw OrderNotFoundException(command.orderId)

        // Execute business logic
        order.confirm()

        // Save aggregate
        orderRepository.save(order)

        // Publish events
        order.events.forEach { eventPublisher.publish(it) }
    }
}
```

### 7. Factories

Complex object creation logic.

```kotlin
// Factory for complex aggregate creation
object OrderFactory {

    fun createFromCart(
        cart: Cart,
        shippingAddress: Address,
        billingAddress: Address
    ): Order {
        require(cart.items.isNotEmpty()) { "Cannot create order from empty cart" }

        val order = Order.create(cart.customerId)

        // Transfer cart items to order
        cart.items.forEach { cartItem ->
            order.addItem(
                productId = cartItem.productId,
                quantity = cartItem.quantity,
                unitPrice = cartItem.currentPrice
            )
        }

        order.setShippingAddress(shippingAddress)
        order.setBillingAddress(billingAddress)

        return order
    }

    fun createSubscriptionOrder(
        customerId: CustomerId,
        subscription: Subscription
    ): Order {
        val order = Order.create(customerId)

        subscription.items.forEach { item ->
            order.addItem(
                productId = item.productId,
                quantity = item.quantity,
                unitPrice = item.recurringPrice
            )
        }

        order.markAsSubscriptionOrder(subscription.id)

        return order
    }
}
```

## Implementation Examples

### Complete Bounded Context: Catalog

```kotlin
// ============================================
// DOMAIN LAYER
// ============================================

// domain/model/Product.kt (Aggregate Root)
class Product private constructor(
    val id: ProductId,
    var name: ProductName,
    var description: ProductDescription,
    var price: Money,
    var stock: Stock,
    val categoryId: CategoryId,
    private val _images: MutableList<ProductImage> = mutableListOf(),
    private val _events: MutableList<DomainEvent> = mutableListOf()
) {
    val images: List<ProductImage> get() = _images.toList()
    val events: List<DomainEvent> get() = _events.toList()

    companion object {
        fun create(
            name: ProductName,
            description: ProductDescription,
            price: Money,
            categoryId: CategoryId,
            initialStock: Stock
        ): Product {
            require(price.isPositive()) { "Price must be positive" }

            val product = Product(
                id = ProductId.generate(),
                name = name,
                description = description,
                price = price,
                stock = initialStock,
                categoryId = categoryId
            )

            product.addEvent(ProductCreated(product.id, name.value, price))

            return product
        }
    }

    fun changePrice(newPrice: Money, changedBy: UserId) {
        require(newPrice.isPositive()) { "Price must be positive" }

        val oldPrice = this.price
        this.price = newPrice

        addEvent(ProductPriceChanged(id, oldPrice, newPrice, changedBy))
    }

    fun updateStock(quantity: Int) {
        val oldStock = stock.quantity
        stock = Stock(quantity)

        if (stock.quantity == 0 && oldStock > 0) {
            addEvent(ProductOutOfStock(id))
        }
    }

    fun addImage(image: ProductImage) {
        require(_images.size < 10) { "Cannot add more than 10 images" }
        _images.add(image)
    }

    fun isAvailable(): Boolean = stock.quantity > 0

    private fun addEvent(event: DomainEvent) {
        _events.add(event)
    }
}

// domain/model/ProductImage.kt (Entity within aggregate)
data class ProductImage(
    val id: ImageId,
    val url: ImageUrl,
    val altText: String,
    val order: Int
)

// domain/model/value objects
@JvmInline
value class ProductId(val value: UUID) {
    companion object {
        fun generate() = ProductId(UUID.randomUUID())
    }
}

@JvmInline
value class ProductName(val value: String) {
    init {
        require(value.isNotBlank()) { "Product name cannot be blank" }
        require(value.length <= 150) { "Product name too long" }
    }
}

data class Stock(val quantity: Int) {
    init {
        require(quantity >= 0) { "Stock cannot be negative" }
    }

    fun hasEnough(requested: Int): Boolean = quantity >= requested
}

// domain/repository/ProductRepository.kt
interface ProductRepository {
    suspend fun save(product: Product): Product
    suspend fun findById(id: ProductId): Product?
    fun findByCategoryId(categoryId: CategoryId): Flow<Product>
    fun findAll(): Flow<Product>
}

// domain/service/InventoryService.kt
class InventoryService(
    private val productRepository: ProductRepository
) {
    suspend fun reserveStock(productId: ProductId, quantity: Int): ReservationResult {
        val product = productRepository.findById(productId)
            ?: return ReservationResult.ProductNotFound

        if (!product.stock.hasEnough(quantity)) {
            return ReservationResult.InsufficientStock(product.stock.quantity)
        }

        product.updateStock(product.stock.quantity - quantity)
        productRepository.save(product)

        return ReservationResult.Success
    }
}

sealed class ReservationResult {
    object Success : ReservationResult()
    object ProductNotFound : ReservationResult()
    data class InsufficientStock(val available: Int) : ReservationResult()
}

// ============================================
// APPLICATION LAYER
// ============================================

// application/command/CreateProductCommand.kt
data class CreateProductCommand(
    val name: String,
    val description: String,
    val price: BigDecimal,
    val currency: String,
    val categoryId: String,
    val initialStock: Int
)

// application/command/CreateProductHandler.kt
@Service
class CreateProductHandler(
    private val productRepository: ProductRepository,
    private val categoryRepository: CategoryRepository,
    private val eventPublisher: EventPublisher
) {
    @Transactional
    suspend fun execute(command: CreateProductCommand): ProductId {
        // Validate category exists
        val categoryId = CategoryId(UUID.fromString(command.categoryId))
        categoryRepository.findById(categoryId)
            ?: throw CategoryNotFoundException(categoryId)

        // Create domain objects
        val product = Product.create(
            name = ProductName(command.name),
            description = ProductDescription(command.description),
            price = Money(command.price, Currency.getInstance(command.currency)),
            categoryId = categoryId,
            initialStock = Stock(command.initialStock)
        )

        // Persist
        productRepository.save(product)

        // Publish events
        product.events.forEach { eventPublisher.publish(it) }

        return product.id
    }
}
```

## Best Practices

### 1. Always Use Ubiquitous Language

```kotlin
// ❌ BAD - Technical language
class ProductRecord {
    var field1: String = ""
    var field2: BigDecimal = BigDecimal.ZERO
}

// ✅ GOOD - Business language
class Product {
    var name: ProductName
    var price: Money
}
```

### 2. Protect Invariants in Aggregates

```kotlin
// ❌ BAD - No protection
class Order {
    val items: MutableList<OrderItem> = mutableListOf()
}
// Anyone can modify items directly, breaking invariants

// ✅ GOOD - Encapsulation
class Order {
    private val _items: MutableList<OrderItem> = mutableListOf()
    val items: List<OrderItem> get() = _items.toList()

    fun addItem(item: OrderItem) {
        require(status == OrderStatus.DRAFT) { "Cannot modify confirmed order" }
        _items.add(item)
    }
}
```

### 3. Reference Other Aggregates by ID

```kotlin
// ❌ BAD - Holding reference to another aggregate
class Order {
    val customer: Customer  // Another aggregate
}

// ✅ GOOD - Reference by ID
class Order {
    val customerId: CustomerId
}
```

### 4. Keep Aggregates Small

```kotlin
// ❌ BAD - Too much in one aggregate
class Order {
    val customer: Customer
    val items: List<OrderItem>
    val payment: Payment
    val shipping: ShippingInfo
    val invoice: Invoice
    val reviews: List<Review>
}

// ✅ GOOD - Separate aggregates
class Order {
    val customerId: CustomerId
    val items: List<OrderItem>
}

class Payment {
    val orderId: OrderId
}

class Shipment {
    val orderId: OrderId
}
```

### 5. Use Value Objects Liberally

```kotlin
// ❌ BAD - Primitive obsession
data class Product(
    val name: String,
    val price: BigDecimal
)

// ✅ GOOD - Rich model
data class Product(
    val name: ProductName,
    val price: Money
)
```

## Anti-Patterns to Avoid

### 1. Anemic Domain Model

```kotlin
// ❌ ANTI-PATTERN
class Order {
    var status: String = "DRAFT"
    val items: MutableList<OrderItem> = mutableListOf()
}

class OrderService {
    fun confirmOrder(order: Order) {
        if (order.status != "DRAFT") throw Exception()
        order.status = "CONFIRMED"
    }
}

// ✅ CORRECT
class Order {
    private var status: OrderStatus = OrderStatus.DRAFT

    fun confirm() {
        require(status == OrderStatus.DRAFT)
        status = OrderStatus.CONFIRMED
    }
}
```

### 2. Exposing Mutable Collections

```kotlin
// ❌ ANTI-PATTERN
class Order {
    val items: MutableList<OrderItem> = mutableListOf()
}

// ✅ CORRECT
class Order {
    private val _items: MutableList<OrderItem> = mutableListOf()
    val items: List<OrderItem> get() = _items.toList()

    fun addItem(item: OrderItem) { ... }
}
```

### 3. Large Aggregates

Keep aggregates small and focused on a single transactional boundary.

## Summary

DDD provides:
- Clear domain boundaries (Bounded Contexts)
- Rich domain models (Entities, Value Objects, Aggregates)
- Ubiquitous language shared with business
- Strategic and tactical patterns

Key principles:
1. Model the domain, not the database
2. Use ubiquitous language
3. Protect business invariants
4. Keep aggregates small
5. Reference other aggregates by ID
6. Use domain events for communication

---

**Version**: 1.0
**Last Updated**: 2025-11-29
