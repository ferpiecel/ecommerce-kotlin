# Bounded Contexts Documentation

## Overview

This document defines all bounded contexts in the ShopNow e-commerce platform, their responsibilities, aggregates, and how they communicate.

## Context Map

```
                          ┌─────────────────┐
                          │    Identity     │
                          │    Context      │
                          └────────┬────────┘
                                   │ (provides auth)
                    ┌──────────────┼──────────────┐
                    │              │              │
           ┌────────▼────────┐    │    ┌─────────▼────────┐
           │    Catalog      │    │    │    Shopping      │
           │    Context      │    │    │    Context       │
           └────────┬────────┘    │    └─────────┬────────┘
                    │             │              │
                    │ (events)    │              │ (events)
                    │             │              │
           ┌────────▼─────────────▼──────────────▼────────┐
           │              Order Context                    │
           └────────┬──────────────────────────┬───────────┘
                    │                          │
        (events)    │                          │ (events)
                    │                          │
    ┌───────────────▼───────┐      ┌──────────▼──────────┐
    │   Payment Context     │      │  Shipping Context   │
    └───────────────────────┘      └─────────────────────┘
                    │                          │
                    │                          │
                    └──────────┬───────────────┘
                               │ (events)
                    ┌──────────▼──────────┐
                    │   Notification      │
                    │   Context           │
                    └─────────────────────┘
```

---

## 1. Catalog Context

### Responsibility
Manage product catalog, categories, inventory, and product-related information.

### Ubiquitous Language
- **Product**: Item for sale with SKU, name, description, price
- **Category**: Hierarchical classification of products
- **Inventory**: Stock quantity and availability
- **ProductImage**: Visual representation of product
- **SKU**: Stock Keeping Unit - unique product identifier

### Aggregates

#### Product (Aggregate Root)
```kotlin
class Product(
    val id: ProductId,
    val sku: SKU,
    var name: ProductName,
    var description: ProductDescription,
    var price: Money,
    var stock: Stock,
    val categoryId: CategoryId,
    val images: List<ProductImage>
)
```

**Invariants**:
- Price must be positive
- Stock cannot be negative
- SKU must be unique
- At least one product image required

**Commands**:
- CreateProduct
- UpdateProductInfo
- ChangeProductPrice
- AdjustStock
- AddProductImage
- RemoveProductImage
- ArchiveProduct

**Events**:
- ProductCreated
- ProductPriceChanged
- ProductStockAdjusted
- ProductOutOfStock
- ProductRestocked
- ProductArchived

#### Category (Aggregate Root)
```kotlin
class Category(
    val id: CategoryId,
    var name: CategoryName,
    var description: String,
    val parentId: CategoryId?
)
```

**Invariants**:
- Name must be unique within parent
- Cannot create circular parent relationships

**Commands**:
- CreateCategory
- UpdateCategory
- MoveCategory
- DeleteCategory

**Events**:
- CategoryCreated
- CategoryUpdated
- CategoryMoved

### Database Schema
```sql
CREATE SCHEMA catalog;

CREATE TABLE catalog.categories (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES catalog.categories(id),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE catalog.products (
    id UUID PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    category_id UUID NOT NULL REFERENCES catalog.categories(id),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    archived BOOLEAN DEFAULT FALSE
);

CREATE TABLE catalog.product_images (
    id UUID PRIMARY KEY,
    product_id UUID NOT NULL REFERENCES catalog.products(id),
    url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255),
    display_order INTEGER NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_products_category ON catalog.products(category_id);
CREATE INDEX idx_products_sku ON catalog.products(sku);
```

### External Dependencies
- None (core context)

### Publishes Events To
- Order Context (ProductPriceChanged, ProductOutOfStock)
- Notification Context (ProductOutOfStock)

---

## 2. Identity & Access Context

### Responsibility
Manage user identity, authentication, authorization, and access control.

### Ubiquitous Language
- **User**: Person with account in the system
- **Credentials**: Username/email and password
- **Role**: Set of permissions
- **Permission**: Specific action user can perform
- **Session**: Authenticated user session

### Aggregates

#### User (Aggregate Root)
```kotlin
class User(
    val id: UserId,
    var email: Email,
    var username: Username,
    private var passwordHash: PasswordHash,
    var profile: UserProfile,
    var status: UserStatus,
    private val roles: MutableSet<RoleId>
)
```

**Invariants**:
- Email must be unique and valid
- Username must be unique
- Password must meet security requirements
- Cannot delete user with active orders

**Commands**:
- RegisterUser
- UpdateUserProfile
- ChangePassword
- AssignRole
- RevokeRole
- ActivateUser
- DeactivateUser
- DeleteUser

**Events**:
- UserRegistered
- UserActivated
- UserDeactivated
- RoleAssigned
- RoleRevoked
- PasswordChanged

#### Role (Aggregate Root)
```kotlin
class Role(
    val id: RoleId,
    var name: RoleName,
    private val permissions: Set<Permission>
)
```

### Database Schema
```sql
CREATE SCHEMA identity;

CREATE TABLE identity.users (
    id UUID PRIMARY KEY,
    email VARCHAR(100) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    date_of_birth DATE,
    status VARCHAR(20) NOT NULL,
    registered_at TIMESTAMP NOT NULL,
    last_login_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE identity.roles (
    id UUID PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE identity.user_roles (
    user_id UUID NOT NULL REFERENCES identity.users(id),
    role_id UUID NOT NULL REFERENCES identity.roles(id),
    assigned_at TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE identity.permissions (
    id UUID PRIMARY KEY,
    code VARCHAR(100) UNIQUE NOT NULL,
    description TEXT
);

CREATE TABLE identity.role_permissions (
    role_id UUID NOT NULL REFERENCES identity.roles(id),
    permission_id UUID NOT NULL REFERENCES identity.permissions(id),
    PRIMARY KEY (role_id, permission_id)
);
```

### Publishes Events To
- Notification Context (UserRegistered, PasswordChanged)
- Audit Context (UserActivated, UserDeactivated)

---

## 3. Shopping Context

### Responsibility
Manage shopping cart, wishlist, product reviews, and customer feedback.

### Ubiquitous Language
- **Cart**: Temporary collection of items user intends to purchase
- **CartItem**: Product and quantity in cart
- **Wishlist**: Saved products for future consideration
- **Review**: Customer rating and comments on product
- **Rating**: Numeric score (1-5)

### Aggregates

#### Cart (Aggregate Root)
```kotlin
class Cart(
    val id: CartId,
    val customerId: CustomerId,
    private val items: MutableList<CartItem>,
    var lastModified: Instant
)
```

**Invariants**:
- Cannot add item with zero quantity
- Cannot add more items than available stock
- Cart expires after 30 days of inactivity

**Commands**:
- AddItemToCart
- RemoveItemFromCart
- UpdateItemQuantity
- ClearCart
- ConvertCartToOrder

**Events**:
- ItemAddedToCart
- ItemRemovedFromCart
- CartCleared
- CartAbandoned (after timeout)

#### Wishlist (Aggregate Root)
```kotlin
class Wishlist(
    val id: WishlistId,
    val customerId: CustomerId,
    private val items: MutableSet<ProductId>
)
```

#### Review (Aggregate Root)
```kotlin
class Review(
    val id: ReviewId,
    val productId: ProductId,
    val customerId: CustomerId,
    var rating: Rating,
    var comment: ReviewComment,
    val verifiedPurchase: Boolean,
    var status: ReviewStatus
)
```

**Invariants**:
- Customer can only review products they purchased
- Rating must be 1-5
- Cannot modify review after 30 days

### Database Schema
```sql
CREATE SCHEMA shopping;

CREATE TABLE shopping.carts (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    last_modified_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL
);

CREATE TABLE shopping.cart_items (
    id UUID PRIMARY KEY,
    cart_id UUID NOT NULL REFERENCES shopping.carts(id),
    product_id UUID NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    added_at TIMESTAMP NOT NULL,
    UNIQUE(cart_id, product_id)
);

CREATE TABLE shopping.wishlists (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE shopping.wishlist_items (
    wishlist_id UUID NOT NULL REFERENCES shopping.wishlists(id),
    product_id UUID NOT NULL,
    added_at TIMESTAMP NOT NULL,
    PRIMARY KEY (wishlist_id, product_id)
);

CREATE TABLE shopping.reviews (
    id UUID PRIMARY KEY,
    product_id UUID NOT NULL,
    customer_id UUID NOT NULL,
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    verified_purchase BOOLEAN NOT NULL,
    status VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    UNIQUE(product_id, customer_id)
);
```

### Consumes Events From
- Catalog Context (ProductPriceChanged, ProductOutOfStock)

### Publishes Events To
- Order Context (CartConvertedToOrder)
- Notification Context (CartAbandoned)

---

## 4. Order Management Context

### Responsibility
Process and manage customer orders, order lifecycle, and returns.

### Ubiquitous Language
- **Order**: Customer's purchase request
- **OrderLine**: Individual product and quantity in order
- **OrderStatus**: Current state of order (Draft, Confirmed, Paid, Shipped, Delivered, Cancelled)
- **Return**: Request to return purchased items
- **Refund**: Money returned to customer

### Aggregates

#### Order (Aggregate Root)
```kotlin
class Order(
    val id: OrderId,
    val customerId: CustomerId,
    var status: OrderStatus,
    private val lines: MutableList<OrderLine>,
    val shippingAddressId: AddressId,
    val billingAddressId: AddressId,
    var placedAt: Instant?,
    var confirmedAt: Instant?,
    val subtotal: Money,
    val tax: Money,
    val shippingCost: Money,
    val total: Money
)
```

**Invariants**:
- Order must have at least one line item
- Cannot modify confirmed order
- Total = Subtotal + Tax + ShippingCost
- Cannot ship order before payment

**Commands**:
- CreateOrder
- AddOrderLine
- RemoveOrderLine
- ConfirmOrder
- CancelOrder
- MarkAsPaid
- MarkAsShipped
- MarkAsDelivered

**Events**:
- OrderCreated
- OrderConfirmed
- OrderPaid
- OrderShipped
- OrderDelivered
- OrderCancelled

#### Return (Aggregate Root)
```kotlin
class Return(
    val id: ReturnId,
    val orderId: OrderId,
    val customerId: CustomerId,
    val items: List<ReturnItem>,
    val reason: ReturnReason,
    var status: ReturnStatus,
    val requestedAt: Instant
)
```

**Invariants**:
- Can only return within 30 days of delivery
- Cannot return more than purchased quantity
- Must provide reason

**Events**:
- ReturnRequested
- ReturnApproved
- ReturnRejected
- RefundProcessed

### Database Schema
```sql
CREATE SCHEMA orders;

CREATE TYPE orders.order_status AS ENUM (
    'DRAFT', 'CONFIRMED', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELLED'
);

CREATE TABLE orders.orders (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    status orders.order_status NOT NULL,
    shipping_address_id UUID NOT NULL,
    billing_address_id UUID NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    tax DECIMAL(10, 2) NOT NULL,
    shipping_cost DECIMAL(10, 2) NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    placed_at TIMESTAMP,
    confirmed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE orders.order_lines (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders.orders(id),
    product_id UUID NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL
);

CREATE TYPE orders.return_status AS ENUM (
    'REQUESTED', 'APPROVED', 'REJECTED', 'RECEIVED', 'REFUNDED'
);

CREATE TABLE orders.returns (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders.orders(id),
    customer_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status orders.return_status NOT NULL,
    requested_at TIMESTAMP NOT NULL,
    processed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE orders.return_items (
    id UUID PRIMARY KEY,
    return_id UUID NOT NULL REFERENCES orders.returns(id),
    order_line_id UUID NOT NULL REFERENCES orders.order_lines(id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMP NOT NULL
);
```

### Consumes Events From
- Shopping Context (CartConvertedToOrder)
- Payment Context (PaymentCompleted)
- Shipping Context (ShipmentDelivered)

### Publishes Events To
- Payment Context (OrderConfirmed)
- Shipping Context (OrderPaid)
- Catalog Context (OrderCancelled - to restore inventory)
- Notification Context (All order events)

---

## 5. Payment Context

### Responsibility
Handle payment processing, payment methods, and transaction management.

### Ubiquitous Language
- **Payment**: Financial transaction for order
- **PaymentMethod**: Way to pay (credit card, PayPal, etc.)
- **Transaction**: Record of payment attempt
- **Refund**: Reversal of payment

### Aggregates

#### Payment (Aggregate Root)
```kotlin
class Payment(
    val id: PaymentId,
    val orderId: OrderId,
    val amount: Money,
    val method: PaymentMethod,
    var status: PaymentStatus,
    val transactionId: String?,
    val processedAt: Instant?
)
```

**Invariants**:
- Amount must match order total
- Cannot process payment twice
- Refund cannot exceed original payment

**Commands**:
- ProcessPayment
- RefundPayment
- CancelPayment

**Events**:
- PaymentProcessed
- PaymentFailed
- PaymentRefunded

### Database Schema
```sql
CREATE SCHEMA payment;

CREATE TYPE payment.payment_status AS ENUM (
    'PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'REFUNDED'
);

CREATE TYPE payment.payment_method_type AS ENUM (
    'CREDIT_CARD', 'DEBIT_CARD', 'PAYPAL', 'BANK_TRANSFER'
);

CREATE TABLE payment.payments (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL UNIQUE,
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    method payment.payment_method_type NOT NULL,
    status payment.payment_status NOT NULL,
    transaction_id VARCHAR(100),
    gateway_response JSONB,
    processed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE payment.refunds (
    id UUID PRIMARY KEY,
    payment_id UUID NOT NULL REFERENCES payment.payments(id),
    amount DECIMAL(10, 2) NOT NULL,
    reason TEXT,
    transaction_id VARCHAR(100),
    processed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL
);
```

### Consumes Events From
- Order Context (OrderConfirmed)

### Publishes Events To
- Order Context (PaymentCompleted, PaymentFailed)
- Notification Context (PaymentCompleted, PaymentFailed)

---

## 6. Shipping Context

### Responsibility
Manage shipping addresses, shipping methods, tracking, and delivery.

### Ubiquitous Language
- **Address**: Delivery location
- **ShippingMethod**: Shipping carrier and service level
- **Shipment**: Physical delivery of order
- **TrackingNumber**: Carrier-provided tracking code

### Aggregates

#### Shipment (Aggregate Root)
```kotlin
class Shipment(
    val id: ShipmentId,
    val orderId: OrderId,
    val shippingAddress: Address,
    val method: ShippingMethod,
    var trackingNumber: TrackingNumber?,
    var status: ShipmentStatus,
    val shippedAt: Instant?,
    val deliveredAt: Instant?
)
```

**Invariants**:
- Cannot ship without tracking number
- Cannot deliver before shipping
- Address must be complete and valid

**Commands**:
- CreateShipment
- AssignTrackingNumber
- MarkAsShipped
- UpdateShipmentStatus
- MarkAsDelivered

**Events**:
- ShipmentCreated
- ShipmentShipped
- ShipmentInTransit
- ShipmentDelivered
- ShipmentFailed

### Database Schema
```sql
CREATE SCHEMA shipping;

CREATE TYPE shipping.shipment_status AS ENUM (
    'PENDING', 'PREPARING', 'SHIPPED', 'IN_TRANSIT', 'DELIVERED', 'FAILED'
);

CREATE TABLE shipping.addresses (
    id UUID PRIMARY KEY,
    customer_id UUID NOT NULL,
    street_address VARCHAR(150) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(50) NOT NULL,
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE shipping.shipping_methods (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    carrier VARCHAR(100) NOT NULL,
    estimated_days INTEGER,
    cost DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL
);

CREATE TABLE shipping.shipments (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL UNIQUE,
    shipping_address_id UUID NOT NULL REFERENCES shipping.addresses(id),
    shipping_method_id UUID NOT NULL REFERENCES shipping.shipping_methods(id),
    tracking_number VARCHAR(100),
    status shipping.shipment_status NOT NULL,
    shipped_at TIMESTAMP,
    estimated_delivery_at TIMESTAMP,
    delivered_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE shipping.shipment_events (
    id UUID PRIMARY KEY,
    shipment_id UUID NOT NULL REFERENCES shipping.shipments(id),
    status shipping.shipment_status NOT NULL,
    location VARCHAR(255),
    description TEXT,
    occurred_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL
);
```

### Consumes Events From
- Order Context (OrderPaid)

### Publishes Events To
- Order Context (ShipmentDelivered)
- Notification Context (ShipmentShipped, ShipmentDelivered)

---

## 7. Promotion Context

### Responsibility
Manage discounts, coupons, promotional banners, and pricing rules.

### Ubiquitous Language
- **Discount**: Percentage or fixed amount reduction
- **Coupon**: Code for discount
- **Promotion**: Time-bound marketing campaign
- **PromoBanner**: Visual advertising element

### Aggregates

#### Promotion (Aggregate Root)
```kotlin
class Promotion(
    val id: PromotionId,
    val code: PromotionCode,
    var discountType: DiscountType,
    var discountValue: BigDecimal,
    val validFrom: Instant,
    val validUntil: Instant,
    val minimumPurchase: Money?,
    val applicableCategories: Set<CategoryId>,
    var usageLimit: Int?,
    var timesUsed: Int
)
```

### Database Schema
```sql
CREATE SCHEMA promotion;

CREATE TYPE promotion.discount_type AS ENUM (
    'PERCENTAGE', 'FIXED_AMOUNT', 'FREE_SHIPPING'
);

CREATE TABLE promotion.promotions (
    id UUID PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    discount_type promotion.discount_type NOT NULL,
    discount_value DECIMAL(10, 2) NOT NULL,
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP NOT NULL,
    minimum_purchase DECIMAL(10, 2),
    usage_limit INTEGER,
    times_used INTEGER DEFAULT 0,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE promotion.promotion_categories (
    promotion_id UUID NOT NULL REFERENCES promotion.promotions(id),
    category_id UUID NOT NULL,
    PRIMARY KEY (promotion_id, category_id)
);
```

---

## 8. Notification Context

### Responsibility
Send notifications to users about important events.

### Aggregates

#### Notification (Aggregate Root)
```kotlin
class Notification(
    val id: NotificationId,
    val userId: UserId,
    val type: NotificationType,
    val message: NotificationMessage,
    var status: NotificationStatus,
    val sentAt: Instant?
)
```

### Database Schema
```sql
CREATE SCHEMA notification;

CREATE TYPE notification.notification_type AS ENUM (
    'ORDER_CONFIRMED', 'ORDER_SHIPPED', 'PAYMENT_RECEIVED', 'PRODUCT_BACK_IN_STOCK'
);

CREATE TABLE notification.notifications (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    type notification.notification_type NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL,
    sent_at TIMESTAMP,
    read_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL
);
```

---

## Context Integration Patterns

### 1. Event-Driven Communication

```kotlin
// Catalog Context publishes
eventPublisher.publish(ProductOutOfStock(productId))

// Shopping Context listens
@EventHandler
fun handle(event: ProductOutOfStock) {
    // Remove from carts
    cartService.removeUnavailableProduct(event.productId)
}
```

### 2. Anti-Corruption Layer

```kotlin
// Order Context needs product info from Catalog
class CatalogAdapter(
    private val catalogClient: CatalogClient
) {
    fun getProductForOrder(productId: ProductId): OrderProductInfo {
        val catalogProduct = catalogClient.getProduct(productId)

        // Transform to Order Context's model
        return OrderProductInfo(
            productId = OrderProductId(catalogProduct.id),
            name = catalogProduct.name,
            price = Money(catalogProduct.currentPrice)
        )
    }
}
```

### 3. Shared Kernel

```kotlin
// shared/domain/Money.kt
// Used across ALL contexts
data class Money(
    val amount: BigDecimal,
    val currency: Currency
)

// shared/domain/DomainEvent.kt
interface DomainEvent {
    val occurredOn: Instant
}
```

---

**Version**: 1.0
**Last Updated**: 2025-11-29
