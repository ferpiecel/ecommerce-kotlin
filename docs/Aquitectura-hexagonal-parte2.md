## 2.6 Agregados (Aggregates)

### ¿Qué es un Agregado?

Un Agregado es un grupo de objetos relacionados que se tratan como una unidad para propósitos de cambios de datos. Tiene una **raíz** (Aggregate Root) que es el único punto de entrada al agregado.

### El problema que resuelve

Imagina un Pedido con sus Líneas de Pedido. Si cualquier parte del código puede modificar directamente una línea, ¿cómo garantizas que:
- El total del pedido se recalcula correctamente?
- No se agregan líneas a un pedido ya enviado?
- El inventario se actualiza consistentemente?

Sin control, terminas con datos inconsistentes y reglas de negocio dispersas por todo el código.

### La solución: Aggregate Root

El Agregado establece una frontera de consistencia. La raíz del agregado (Aggregate Root) es el guardián que:

1. **Controla todo acceso** a los objetos internos
2. **Garantiza las invariantes** (reglas que siempre deben cumplirse)
3. **Es el único objeto referenciable desde fuera** del agregado

### Visualización

```
┌─────────────────────────────────────────────────────────┐
│                    AGREGADO: PEDIDO                      │
│                                                          │
│    ┌─────────────────────────────────────────────┐      │
│    │         ORDER (Aggregate Root)               │      │
│    │                                              │      │
│    │  - Solo yo puedo modificar mis líneas       │      │
│    │  - Yo garantizo que el total es correcto    │      │
│    │  - Yo verifico las reglas de negocio        │      │
│    └─────────────────────────────────────────────┘      │
│                         │                                │
│                         │ controla                       │
│                         ▼                                │
│    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │
│    │  OrderItem   │ │  OrderItem   │ │  OrderItem   │   │
│    │  (interno)   │ │  (interno)   │ │  (interno)   │   │
│    └──────────────┘ └──────────────┘ └──────────────┘   │
│                                                          │
│    Nadie de afuera puede acceder directamente           │
│    a los OrderItems                                      │
└─────────────────────────────────────────────────────────┘
```

### Reglas de los Agregados

1. **La raíz tiene identidad global**: Se puede referenciar desde cualquier parte
2. **Los objetos internos tienen identidad local**: Solo tienen sentido dentro del agregado
3. **Nada externo guarda referencias a objetos internos**: Solo a la raíz
4. **La raíz garantiza las invariantes**: Todas las reglas de consistencia
5. **Los agregados se persisten completos**: Se guardan y cargan como unidad

### Ejemplo en código (Java 21)

```java
// domain/aggregate/Order.java - Aggregate Root

public class Order {
    
    private final OrderId id;
    private final CustomerId customerId;
    private final Instant createdAt;
    private List<OrderItem> items;  // Objetos internos del agregado
    private OrderStatus status;
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    private Order(OrderId id, CustomerId customerId) {
        this.id = id;
        this.customerId = customerId;
        this.items = new ArrayList<>();
        this.status = OrderStatus.PENDING;
        this.createdAt = Instant.now();
    }

    public static Order create(CustomerId customerId) {
        var order = new Order(OrderId.generate(), customerId);
        order.recordEvent(new OrderCreatedEvent(order.id, customerId));
        return order;
    }

    // Para reconstruir desde persistencia
    public static Order reconstitute(
            OrderId id,
            CustomerId customerId,
            List<OrderItem> items,
            OrderStatus status,
            Instant createdAt) {
        var order = new Order(id, customerId);
        order.items = new ArrayList<>(items);
        order.status = status;
        return order;
    }

    // El mundo exterior pide agregar un item
    // Order decide cómo hacerlo y verifica las reglas
    public void addItem(Product product, int quantity) {
        ensureCanBeModified();
        
        if (quantity <= 0) {
            throw new InvalidQuantityException(quantity);
        }

        findItemByProduct(product.getId())
            .ifPresentOrElse(
                existingItem -> existingItem.increaseQuantity(quantity),
                () -> items.add(OrderItem.create(product, quantity))
            );
        
        recordEvent(new OrderItemAddedEvent(id, product.getId(), quantity));
    }

    public void removeItem(ProductId productId) {
        ensureCanBeModified();
        
        var removed = items.removeIf(item -> item.getProductId().equals(productId));
        if (!removed) {
            throw new OrderItemNotFoundException(id, productId);
        }
        
        recordEvent(new OrderItemRemovedEvent(id, productId));
    }

    public void confirm() {
        if (items.isEmpty()) {
            throw new EmptyOrderCannotBeConfirmedException(id);
        }
        
        if (status != OrderStatus.PENDING) {
            throw new InvalidOrderStateTransitionException(status, OrderStatus.CONFIRMED);
        }
        
        this.status = OrderStatus.CONFIRMED;
        
        recordEvent(new OrderConfirmedEvent(
            id,
            customerId,
            calculateTotal(),
            getItemsSummary()
        ));
    }

    public void cancel(String reason) {
        if (!status.canBeCancelled()) {
            throw new OrderCannotBeCancelledException(id, status);
        }
        
        this.status = OrderStatus.CANCELLED;
        recordEvent(new OrderCancelledEvent(id, reason));
    }

    public void markAsPaid(String transactionId) {
        if (status != OrderStatus.CONFIRMED) {
            throw new InvalidOrderStateTransitionException(status, OrderStatus.PAID);
        }
        
        this.status = OrderStatus.PAID;
        recordEvent(new OrderPaidEvent(id, transactionId, calculateTotal()));
    }

    public Money calculateTotal() {
        return items.stream()
            .map(OrderItem::subtotal)
            .reduce(Money.zero(Currency.USD), Money::add);
    }

    public List<OrderItemSummary> getItemsSummary() {
        return items.stream()
            .map(item -> new OrderItemSummary(
                item.getProductId().value(),
                item.getProductName(),
                item.getQuantity(),
                item.getUnitPrice()
            ))
            .toList();
    }

    private void ensureCanBeModified() {
        if (status != OrderStatus.PENDING) {
            throw new OrderCannotBeModifiedException(id, status);
        }
    }

    private Optional<OrderItem> findItemByProduct(ProductId productId) {
        return items.stream()
            .filter(item -> item.getProductId().equals(productId))
            .findFirst();
    }

    // Eventos de dominio
    protected void recordEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    public List<DomainEvent> pullDomainEvents() {
        var events = List.copyOf(domainEvents);
        domainEvents.clear();
        return events;
    }

    // Getters
    public OrderId getId() { return id; }
    public CustomerId getCustomerId() { return customerId; }
    public OrderStatus getStatus() { return status; }
    public List<OrderItem> getItems() { return List.copyOf(items); }
    public Instant getCreatedAt() { return createdAt; }
    public int getItemCount() { return items.size(); }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Order other)) return false;
        return id.equals(other.id);
    }

    @Override
    public int hashCode() {
        return Objects.hash(id);
    }
}


// domain/aggregate/OrderItem.java - Entidad interna del agregado

public class OrderItem {
    
    private final ProductId productId;
    private final String productName;
    private final Money unitPrice;
    private int quantity;

    private OrderItem(ProductId productId, String productName, Money unitPrice, int quantity) {
        this.productId = productId;
        this.productName = productName;
        this.unitPrice = unitPrice;
        this.quantity = quantity;
    }

    public static OrderItem create(Product product, int quantity) {
        if (quantity <= 0) {
            throw new InvalidQuantityException(quantity);
        }
        return new OrderItem(
            product.getId(),
            product.getName(),
            product.getPrice(),
            quantity
        );
    }

    public static OrderItem reconstitute(
            ProductId productId,
            String productName,
            Money unitPrice,
            int quantity) {
        return new OrderItem(productId, productName, unitPrice, quantity);
    }

    void increaseQuantity(int amount) {
        if (amount <= 0) {
            throw new InvalidQuantityException(amount);
        }
        this.quantity += amount;
    }

    void decreaseQuantity(int amount) {
        if (amount <= 0 || amount > this.quantity) {
            throw new InvalidQuantityException(amount);
        }
        this.quantity -= amount;
    }

    public Money subtotal() {
        return unitPrice.multiply(quantity);
    }

    // Getters
    public ProductId getProductId() { return productId; }
    public String getProductName() { return productName; }
    public Money getUnitPrice() { return unitPrice; }
    public int getQuantity() { return quantity; }
}


// domain/aggregate/OrderStatus.java - Enum con comportamiento

public enum OrderStatus {
    PENDING {
        @Override
        public boolean canBeCancelled() { return true; }
    },
    CONFIRMED {
        @Override
        public boolean canBeCancelled() { return true; }
    },
    PAID {
        @Override
        public boolean canBeCancelled() { return false; }
    },
    SHIPPED {
        @Override
        public boolean canBeCancelled() { return false; }
    },
    DELIVERED {
        @Override
        public boolean canBeCancelled() { return false; }
    },
    CANCELLED {
        @Override
        public boolean canBeCancelled() { return false; }
    };

    public abstract boolean canBeCancelled();
}
```

## 2.7 Servicios de Dominio (Domain Services)

### ¿Qué es un Servicio de Dominio?

Un Servicio de Dominio encapsula lógica de negocio que **no pertenece naturalmente a ninguna entidad** específica. Es una operación del dominio que involucra múltiples objetos.

### ¿Cuándo usar un Servicio de Dominio?

1. La operación involucra **múltiples agregados**
2. La lógica requiere **información externa** que la entidad no debería conocer
3. Poner la lógica en una entidad la haría **conocer demasiado**

### Ejemplo: Servicio de Pricing (Java 21)

```java
// domain/service/PricingService.java

public class PricingService {
    
    private final PromotionRules promotionRules;
    private final TaxCalculator taxCalculator;

    public PricingService(PromotionRules promotionRules, TaxCalculator taxCalculator) {
        this.promotionRules = promotionRules;
        this.taxCalculator = taxCalculator;
    }

    public PriceCalculation calculatePrice(
            Product product,
            int quantity,
            Customer customer,
            Country shippingCountry) {
        
        // Precio base
        var basePrice = product.getPrice().multiply(quantity);
        var currentPrice = basePrice;
        var appliedDiscounts = new ArrayList<AppliedDiscount>();
        
        // Descuento VIP
        if (customer.isVIP()) {
            var vipDiscount = Percentage.of(10);
            currentPrice = currentPrice.applyDiscount(vipDiscount);
            appliedDiscounts.add(new AppliedDiscount("VIP", vipDiscount));
        }
        
        // Descuento por volumen
        var volumeDiscount = calculateVolumeDiscount(quantity);
        if (!volumeDiscount.isZero()) {
            currentPrice = currentPrice.applyDiscount(volumeDiscount);
            appliedDiscounts.add(new AppliedDiscount("Volume", volumeDiscount));
        }
        
        // Promociones activas
        var promotions = promotionRules.findApplicable(product, customer);
        for (var promo : promotions) {
            currentPrice = promo.applyTo(currentPrice);
            appliedDiscounts.add(new AppliedDiscount(promo.getName(), promo.getDiscount()));
        }
        
        // Impuestos
        var taxes = taxCalculator.calculate(currentPrice, shippingCountry);
        var finalPrice = currentPrice.add(taxes);
        
        return new PriceCalculation(
            basePrice,
            currentPrice,
            taxes,
            finalPrice,
            List.copyOf(appliedDiscounts)
        );
    }

    private Percentage calculateVolumeDiscount(int quantity) {
        if (quantity >= 100) return Percentage.of(15);
        if (quantity >= 50) return Percentage.of(10);
        if (quantity >= 20) return Percentage.of(5);
        return Percentage.zero();
    }
}


// domain/service/PriceCalculation.java - Resultado como record

public record PriceCalculation(
    Money basePrice,
    Money discountedPrice,
    Money taxes,
    Money finalPrice,
    List<AppliedDiscount> appliedDiscounts
) {
    public Money totalSavings() {
        return basePrice.subtract(discountedPrice);
    }
}

public record AppliedDiscount(String name, Percentage percentage) {}
```

### Domain Service vs Application Service

| Aspecto | Domain Service | Application Service |
|---------|---------------|---------------------|
| Contiene | Lógica de negocio | Orquestación |
| Conoce | Entidades, Value Objects | Puertos, repositorios |
| Ejemplo | Calcular precio con reglas | Crear pedido y notificar |
| Dependencias | Solo dominio | Dominio + infraestructura (vía puertos) |

## 2.8 Eventos de Dominio (Domain Events)

### ¿Qué es un Evento de Dominio?

Un Evento de Dominio representa **algo significativo que ocurrió** en el dominio. Es un hecho histórico, inmutable, que otros componentes pueden necesitar conocer.

### Características clave

1. **Describe algo que YA ocurrió** (pasado): `OrderConfirmed`, no `ConfirmOrder`
2. **Es inmutable**: Una vez creado, no cambia
3. **Contiene toda la información necesaria** para que otros reaccionen
4. **Es parte del lenguaje ubicuo**

### Implementación con Sealed Classes (Java 21)

```java
// domain/event/DomainEvent.java

public sealed interface DomainEvent 
    permits OrderCreatedEvent, OrderConfirmedEvent, OrderCancelledEvent, 
            OrderPaidEvent, OrderItemAddedEvent, OrderItemRemovedEvent {
    
    String eventId();
    Instant occurredOn();
    String aggregateId();
    String aggregateType();
    String eventType();
}


// domain/event/OrderCreatedEvent.java

public record OrderCreatedEvent(
    String eventId,
    Instant occurredOn,
    OrderId orderId,
    CustomerId customerId
) implements DomainEvent {
    
    public OrderCreatedEvent(OrderId orderId, CustomerId customerId) {
        this(
            UUID.randomUUID().toString(),
            Instant.now(),
            orderId,
            customerId
        );
    }

    @Override
    public String aggregateId() { return orderId.value(); }
    
    @Override
    public String aggregateType() { return "Order"; }
    
    @Override
    public String eventType() { return "order.created"; }
}


// domain/event/OrderConfirmedEvent.java

public record OrderConfirmedEvent(
    String eventId,
    Instant occurredOn,
    OrderId orderId,
    CustomerId customerId,
    Money totalAmount,
    List<OrderItemSummary> items
) implements DomainEvent {
    
    public OrderConfirmedEvent(
            OrderId orderId, 
            CustomerId customerId, 
            Money totalAmount,
            List<OrderItemSummary> items) {
        this(
            UUID.randomUUID().toString(),
            Instant.now(),
            orderId,
            customerId,
            totalAmount,
            List.copyOf(items)
        );
    }

    @Override
    public String aggregateId() { return orderId.value(); }
    
    @Override
    public String aggregateType() { return "Order"; }
    
    @Override
    public String eventType() { return "order.confirmed"; }
}


// domain/event/OrderItemSummary.java

public record OrderItemSummary(
    String productId,
    String productName,
    int quantity,
    Money unitPrice
) {}
```

## 2.9 Repositorios (Repositories)

### ¿Qué es un Repositorio?

Un Repositorio es una abstracción que simula una **colección de objetos de dominio**. Desde la perspectiva del dominio, es como si todos los agregados estuvieran en memoria.

### Repositorio como Interface (Puerto)

```java
// domain/repository/OrderRepository.java

public interface OrderRepository {
    
    // Comandos (modifican)
    void save(Order order);
    void delete(OrderId id);
    
    // Queries (consultan)
    Optional<Order> findById(OrderId id);
    List<Order> findByCustomer(CustomerId customerId);
    List<Order> findByStatus(OrderStatus status);
    List<Order> findPendingOlderThan(Instant date);
    
    // Paginación
    Page<Order> findAll(Pageable pageable);
    
    // Generación de identidad
    OrderId nextId();
    
    // Verificación de existencia
    boolean existsById(OrderId id);
}


// domain/repository/CustomerRepository.java

public interface CustomerRepository {
    
    void save(Customer customer);
    Optional<Customer> findById(CustomerId id);
    Optional<Customer> findByEmail(Email email);
    boolean existsByEmail(Email email);
    CustomerId nextId();
}


// domain/repository/ProductRepository.java

public interface ProductRepository {
    
    void save(Product product);
    Optional<Product> findById(ProductId id);
    List<Product> findByIds(List<ProductId> ids);
    List<Product> findByCategory(CategoryId categoryId);
    Page<Product> search(ProductSearchCriteria criteria, Pageable pageable);
}
```

---

# 3. Arquitectura Hexagonal: La Estructura Técnica

## 3.1 ¿Qué es la Arquitectura Hexagonal?

La Arquitectura Hexagonal, también llamada **Puertos y Adaptadores**, fue propuesta por Alistair Cockburn en 2005. Su objetivo es crear aplicaciones donde el núcleo de negocio esté completamente aislado del mundo exterior.

### La metáfora del hexágono

```
                    ┌─────────────────┐
                    │   REST API      │
                    │   (Adaptador)   │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   ▼                   │
         │  ┌─────────────────────────────────┐  │
         │  │         PUERTO PRIMARIO         │  │
         │  │     (Interface de entrada)      │  │
┌────────┤  └─────────────────────────────────┘  ├────────┐
│  CLI   │                                       │ GraphQL│
│Adaptador                                       │Adaptador
└────────┤  ┌─────────────────────────────────┐  ├────────┘
         │  │      DOMINIO Y APLICACIÓN       │  │
         │  │    (Lógica de negocio pura)     │  │
         │  └─────────────────────────────────┘  │
         │                                       │
         │  ┌─────────────────────────────────┐  │
         │  │       PUERTO SECUNDARIO         │  │
         │  │      (Interface de salida)      │  │
         └──┴─────────────────────────────────┴──┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │PostgreSQL│  │ RabbitMQ │  │ SendGrid │
        └──────────┘  └──────────┘  └──────────┘
```

## 3.2 Las Tres Zonas

### Zona Interior: Dominio
- Entidades y Value Objects
- Eventos de Dominio
- Servicios de Dominio
- Interfaces de Repositorio

**Regla de oro**: El dominio NO conoce nada del exterior.

### Zona Media: Aplicación
- Servicios de Aplicación
- Handlers de Comandos y Queries
- Handlers de Eventos
- DTOs

**Responsabilidad**: Coordinar. No contiene lógica de negocio.

### Zona Exterior: Infraestructura
- Adaptadores primarios (REST, GraphQL, CLI)
- Adaptadores secundarios (PostgreSQL, Redis, SendGrid)
- Configuración

## 3.3 La Regla de Dependencia

**Las dependencias siempre apuntan hacia adentro.**

```
Infraestructura → Aplicación → Dominio
```