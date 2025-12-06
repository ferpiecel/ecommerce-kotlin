---

# 10. Testing en Arquitectura Hexagonal

## 10.1 Estrategia de Testing por Capas

| Capa | Tipo de Test | Qué se prueba | Dependencias |
|------|--------------|---------------|--------------|
| Dominio | Unit Tests | Entidades, Value Objects, Servicios | Ninguna |
| Aplicación | Integration Tests | Servicios con mocks de puertos | Mocks |
| Infraestructura | Integration Tests | Adaptadores | DB real o Testcontainers |
| Sistema | E2E Tests | Flujos completos | Todo el sistema |

## 10.2 Tests de Dominio (Unit Tests con JUnit 5)

Los tests de dominio son los más valiosos porque no tienen dependencias externas.

```java
// domain/aggregate/OrderTest.java

class OrderTest {
    
    @Nested
    @DisplayName("Order Creation")
    class OrderCreation {
        
        @Test
        @DisplayName("should create order in PENDING status")
        void shouldCreateOrderInPendingStatus() {
            var customerId = CustomerId.of("customer-123");
            
            var order = Order.create(customerId);
            
            assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
            assertThat(order.getCustomerId()).isEqualTo(customerId);
            assertThat(order.getItems()).isEmpty();
            assertThat(order.getId()).isNotNull();
        }
        
        @Test
        @DisplayName("should generate OrderCreatedEvent")
        void shouldGenerateOrderCreatedEvent() {
            var order = Order.create(CustomerId.of("customer-123"));
            
            var events = order.pullDomainEvents();
            
            assertThat(events).hasSize(1);
            assertThat(events.get(0)).isInstanceOf(OrderCreatedEvent.class);
        }
    }
    
    @Nested
    @DisplayName("Adding Items")
    class AddingItems {
        
        private Order order;
        private Product product;
        
        @BeforeEach
        void setUp() {
            order = OrderTestFixtures.createPendingOrder();
            product = ProductTestFixtures.createProduct(Money.of(10, Currency.USD));
        }
        
        @Test
        @DisplayName("should add item to order")
        void shouldAddItemToOrder() {
            order.addItem(product, 2);
            
            assertThat(order.getItems()).hasSize(1);
            assertThat(order.calculateTotal()).isEqualTo(Money.of(20, Currency.USD));
        }
        
        @Test
        @DisplayName("should reject zero quantity")
        void shouldRejectZeroQuantity() {
            assertThatThrownBy(() -> order.addItem(product, 0))
                .isInstanceOf(InvalidQuantityException.class);
        }
        
        @Test
        @DisplayName("should reject negative quantity")
        void shouldRejectNegativeQuantity() {
            assertThatThrownBy(() -> order.addItem(product, -1))
                .isInstanceOf(InvalidQuantityException.class);
        }
        
        @Test
        @DisplayName("should reject adding items to confirmed order")
        void shouldRejectAddingItemsToConfirmedOrder() {
            var confirmedOrder = OrderTestFixtures.createConfirmedOrder();
            
            assertThatThrownBy(() -> confirmedOrder.addItem(product, 1))
                .isInstanceOf(OrderCannotBeModifiedException.class);
        }
        
        @Test
        @DisplayName("should increase quantity for existing product")
        void shouldIncreaseQuantityForExistingProduct() {
            order.addItem(product, 2);
            order.addItem(product, 3);
            
            assertThat(order.getItems()).hasSize(1);
            assertThat(order.getItems().get(0).getQuantity()).isEqualTo(5);
        }
    }
    
    @Nested
    @DisplayName("Order Confirmation")
    class OrderConfirmation {
        
        @Test
        @DisplayName("should change status to CONFIRMED")
        void shouldChangeStatusToConfirmed() {
            var order = OrderTestFixtures.createOrderWithItems();
            
            order.confirm();
            
            assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        }
        
        @Test
        @DisplayName("should generate OrderConfirmedEvent")
        void shouldGenerateOrderConfirmedEvent() {
            var order = OrderTestFixtures.createOrderWithItems();
            order.pullDomainEvents(); // Clear creation event
            
            order.confirm();
            var events = order.pullDomainEvents();
            
            assertThat(events).hasSize(1);
            assertThat(events.get(0)).isInstanceOf(OrderConfirmedEvent.class);
            
            var event = (OrderConfirmedEvent) events.get(0);
            assertThat(event.orderId()).isEqualTo(order.getId());
            assertThat(event.totalAmount()).isEqualTo(order.calculateTotal());
        }
        
        @Test
        @DisplayName("should reject confirming empty order")
        void shouldRejectConfirmingEmptyOrder() {
            var order = OrderTestFixtures.createPendingOrder();
            
            assertThatThrownBy(order::confirm)
                .isInstanceOf(EmptyOrderCannotBeConfirmedException.class);
        }
        
        @Test
        @DisplayName("should reject confirming already confirmed order")
        void shouldRejectConfirmingAlreadyConfirmedOrder() {
            var order = OrderTestFixtures.createConfirmedOrder();
            
            assertThatThrownBy(order::confirm)
                .isInstanceOf(InvalidOrderStateTransitionException.class);
        }
    }
    
    @Nested
    @DisplayName("Total Calculation")
    class TotalCalculation {
        
        @Test
        @DisplayName("should calculate total correctly with multiple items")
        void shouldCalculateTotalCorrectly() {
            var order = OrderTestFixtures.createPendingOrder();
            order.addItem(ProductTestFixtures.createProduct(Money.of(10, Currency.USD)), 2);
            order.addItem(ProductTestFixtures.createProduct(Money.of(15, Currency.USD)), 3);
            
            var total = order.calculateTotal();
            
            assertThat(total).isEqualTo(Money.of(65, Currency.USD)); // 20 + 45
        }
    }
}


// Test fixtures
class OrderTestFixtures {
    
    public static Order createPendingOrder() {
        return Order.create(CustomerId.of("customer-123"));
    }
    
    public static Order createOrderWithItems() {
        var order = createPendingOrder();
        order.addItem(ProductTestFixtures.createProduct(), 1);
        order.pullDomainEvents(); // Clear events
        return order;
    }
    
    public static Order createConfirmedOrder() {
        var order = createOrderWithItems();
        order.confirm();
        order.pullDomainEvents(); // Clear events
        return order;
    }
}

class ProductTestFixtures {
    
    public static Product createProduct() {
        return createProduct(Money.of(10, Currency.USD));
    }
    
    public static Product createProduct(Money price) {
        return Product.create(
            ProductId.generate(),
            "Test Product",
            price
        );
    }
}
```

### Tests de Value Objects

```java
// domain/valueobject/MoneyTest.java

class MoneyTest {
    
    @Nested
    @DisplayName("Money Creation")
    class MoneyCreation {
        
        @Test
        @DisplayName("should create valid money")
        void shouldCreateValidMoney() {
            var money = Money.of(100, Currency.USD);
            
            assertThat(money.amount()).isEqualTo(BigDecimal.valueOf(100));
            assertThat(money.currency()).isEqualTo(Currency.USD);
        }
        
        @Test
        @DisplayName("should reject negative amounts")
        void shouldRejectNegativeAmounts() {
            assertThatThrownBy(() -> Money.of(-10, Currency.USD))
                .isInstanceOf(InvalidMoneyAmountException.class);
        }
        
        @Test
        @DisplayName("should allow zero amount")
        void shouldAllowZeroAmount() {
            var money = Money.zero(Currency.USD);
            
            assertThat(money.amount()).isEqualTo(BigDecimal.ZERO);
        }
    }
    
    @Nested
    @DisplayName("Money Operations")
    class MoneyOperations {
        
        @Test
        @DisplayName("should add correctly")
        void shouldAddCorrectly() {
            var a = Money.of(10, Currency.USD);
            var b = Money.of(20, Currency.USD);
            
            var result = a.add(b);
            
            assertThat(result).isEqualTo(Money.of(30, Currency.USD));
        }
        
        @Test
        @DisplayName("should reject adding different currencies")
        void shouldRejectAddingDifferentCurrencies() {
            var usd = Money.of(10, Currency.USD);
            var eur = Money.of(10, Currency.EUR);
            
            assertThatThrownBy(() -> usd.add(eur))
                .isInstanceOf(CurrencyMismatchException.class);
        }
        
        @Test
        @DisplayName("should multiply correctly")
        void shouldMultiplyCorrectly() {
            var money = Money.of(10, Currency.USD);
            
            var result = money.multiply(3);
            
            assertThat(result).isEqualTo(Money.of(30, Currency.USD));
        }
    }
    
    @Nested
    @DisplayName("Money Equality")
    class MoneyEquality {
        
        @Test
        @DisplayName("should be equal if same amount and currency")
        void shouldBeEqualIfSameAmountAndCurrency() {
            var a = Money.of(100, Currency.USD);
            var b = Money.of(100, Currency.USD);
            
            assertThat(a).isEqualTo(b);
        }
        
        @Test
        @DisplayName("should not be equal if different amount")
        void shouldNotBeEqualIfDifferentAmount() {
            var a = Money.of(100, Currency.USD);
            var b = Money.of(200, Currency.USD);
            
            assertThat(a).isNotEqualTo(b);
        }
        
        @Test
        @DisplayName("should not be equal if different currency")
        void shouldNotBeEqualIfDifferentCurrency() {
            var a = Money.of(100, Currency.USD);
            var b = Money.of(100, Currency.EUR);
            
            assertThat(a).isNotEqualTo(b);
        }
    }
}
```

## 10.3 Tests de Aplicación (con Mocks)

```java
// application/service/OrderCommandServiceTest.java

@ExtendWith(MockitoExtension.class)
class OrderCommandServiceTest {
    
    @Mock
    private OrderRepository orderRepository;
    
    @Mock
    private ProductRepository productRepository;
    
    @Mock
    private EventPublisher eventPublisher;
    
    @InjectMocks
    private OrderCommandService orderService;
    
    @Nested
    @DisplayName("Create Order")
    class CreateOrder {
        
        @Test
        @DisplayName("should create order with valid products")
        void shouldCreateOrderWithValidProducts() {
            var product = ProductTestFixtures.createProduct();
            when(productRepository.findById(any())).thenReturn(Optional.of(product));
            
            var command = new CreateOrderCommand(
                "customer-123",
                List.of(new CreateOrderCommand.OrderItemRequest(product.getId().value(), 2)),
                null
            );
            
            var orderId = orderService.createOrder(command);
            
            assertThat(orderId).isNotNull();
            verify(orderRepository).save(any(Order.class));
            verify(eventPublisher).publishAll(anyList());
        }
        
        @Test
        @DisplayName("should fail if product not found")
        void shouldFailIfProductNotFound() {
            when(productRepository.findById(any())).thenReturn(Optional.empty());
            
            var command = new CreateOrderCommand(
                "customer-123",
                List.of(new CreateOrderCommand.OrderItemRequest("invalid-product", 1)),
                null
            );
            
            assertThatThrownBy(() -> orderService.createOrder(command))
                .isInstanceOf(ProductNotFoundException.class);
            
            verify(orderRepository, never()).save(any());
        }
    }
    
    @Nested
    @DisplayName("Confirm Order")
    class ConfirmOrder {
        
        @Test
        @DisplayName("should confirm existing order")
        void shouldConfirmExistingOrder() {
            var order = OrderTestFixtures.createOrderWithItems();
            when(orderRepository.findById(any())).thenReturn(Optional.of(order));
            
            orderService.confirmOrder(new ConfirmOrderCommand(order.getId().value()));
            
            assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
            verify(orderRepository).save(order);
            verify(eventPublisher).publishAll(anyList());
        }
        
        @Test
        @DisplayName("should fail if order not found")
        void shouldFailIfOrderNotFound() {
            when(orderRepository.findById(any())).thenReturn(Optional.empty());
            
            assertThatThrownBy(() -> 
                orderService.confirmOrder(new ConfirmOrderCommand("invalid-id")))
                .isInstanceOf(OrderNotFoundException.class);
        }
    }
}
```

## 10.4 Tests de Adaptadores con Testcontainers

```java
// infrastructure/adapter/output/persistence/JpaOrderRepositoryIntegrationTest.java

@DataJpaTest
@Testcontainers
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class JpaOrderRepositoryIntegrationTest {
    
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
        .withDatabaseName("testdb")
        .withUsername("test")
        .withPassword("test");
    
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
    
    @Autowired
    private JpaOrderRepository repository;
    
    @Test
    @DisplayName("should save and retrieve order")
    void shouldSaveAndRetrieveOrder() {
        var order = OrderTestFixtures.createOrderWithItems();
        
        repository.save(order);
        var retrieved = repository.findById(order.getId());
        
        assertThat(retrieved).isPresent();
        assertThat(retrieved.get().getId()).isEqualTo(order.getId());
        assertThat(retrieved.get().getStatus()).isEqualTo(order.getStatus());
        assertThat(retrieved.get().getItems()).hasSize(order.getItems().size());
    }
    
    @Test
    @DisplayName("should return empty for non-existent order")
    void shouldReturnEmptyForNonExistentOrder() {
        var result = repository.findById(OrderId.of("non-existent"));
        
        assertThat(result).isEmpty();
    }
    
    @Test
    @DisplayName("should find orders by customer")
    void shouldFindOrdersByCustomer() {
        var customerId = CustomerId.of("customer-123");
        var order1 = createOrderForCustomer(customerId);
        var order2 = createOrderForCustomer(customerId);
        var otherOrder = createOrderForCustomer(CustomerId.of("other-customer"));
        
        repository.save(order1);
        repository.save(order2);
        repository.save(otherOrder);
        
        var results = repository.findByCustomer(customerId);
        
        assertThat(results).hasSize(2);
        assertThat(results).allMatch(o -> o.getCustomerId().equals(customerId));
    }
    
    @Test
    @DisplayName("should update existing order")
    void shouldUpdateExistingOrder() {
        var order = OrderTestFixtures.createOrderWithItems();
        repository.save(order);
        
        order.confirm();
        repository.save(order);
        
        var retrieved = repository.findById(order.getId());
        
        assertThat(retrieved.get().getStatus()).isEqualTo(OrderStatus.CONFIRMED);
    }
    
    private Order createOrderForCustomer(CustomerId customerId) {
        var order = Order.create(customerId);
        order.addItem(ProductTestFixtures.createProduct(), 1);
        order.pullDomainEvents();
        return order;
    }
}
```

---

# 11. Mejores Prácticas y Anti-patrones

## 11.1 Mejores Prácticas

### 1. El Dominio es Sagrado

```java
// ❌ MAL
import jakarta.persistence.*;

public class Order {
    @Id
    private String id;
    
    @Column
    private String status;
}

// ✅ BIEN
public class Order {
    private final OrderId id;
    private OrderStatus status;
    // El dominio no conoce JPA
}
```

### 2. Usa el Lenguaje del Negocio

```java
// ❌ MAL
order.setStatus(2);
order.updateField("confirmed", true);

// ✅ BIEN
order.confirm();
customer.upgradeToPreferredStatus();
```

### 3. Los Value Objects son Baratos, Úsalos

```java
// ❌ MAL
public Order createOrder(String customerId, String email, double total) { }

// ✅ BIEN
public Order createOrder(CustomerId customerId, Email email, Money total) { }
```

### 4. Eventos para Desacoplar

```java
// ❌ MAL
public void confirmOrder(String orderId) {
    order.confirm();
    orderRepository.save(order);
    emailService.sendConfirmation(order);
    inventoryService.reserve(order);
    analyticsService.record(order);
}

// ✅ BIEN
public void confirmOrder(String orderId) {
    order.confirm();
    orderRepository.save(order);
    eventPublisher.publishAll(order.pullDomainEvents());
}
```

## 11.2 Anti-patrones a Evitar

### Anemic Domain Model

```java
// ❌ ANTI-PATRÓN
public class Order {
    private String status;
    
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
}

public class OrderService {
    public void confirmOrder(Order order) {
        if (order.getItems().isEmpty()) throw new Exception();
        order.setStatus("CONFIRMED");
    }
}

// ✅ CORRECTO
public class Order {
    private OrderStatus status;
    
    public void confirm() {
        if (items.isEmpty()) {
            throw new EmptyOrderCannotBeConfirmedException(id);
        }
        this.status = OrderStatus.CONFIRMED;
    }
}
```

### Bypass del Puerto

```java
// ❌ ANTI-PATRÓN
@Service
public class OrderService {
    private final EntityManager entityManager;  // Directamente JPA
    
    public void createOrder(Order order) {
        entityManager.persist(order);
    }
}

// ✅ CORRECTO
@Service
public class OrderService {
    private final OrderRepository orderRepository;  // Puerto
    
    public void createOrder(Order order) {
        orderRepository.save(order);
    }
}
```

## 11.3 Estructura de Proyecto Recomendada

```
src/main/java/com/example/orders/
├── domain/
│   ├── aggregate/
│   │   ├── Order.java
│   │   ├── OrderItem.java
│   │   └── OrderStatus.java
│   ├── valueobject/
│   │   ├── Money.java
│   │   ├── Email.java
│   │   ├── OrderId.java
│   │   └── CustomerId.java
│   ├── event/
│   │   ├── DomainEvent.java
│   │   ├── OrderCreatedEvent.java
│   │   └── OrderConfirmedEvent.java
│   ├── service/
│   │   └── PricingService.java
│   ├── specification/
│   │   └── OrderSpecifications.java
│   ├── repository/
│   │   └── OrderRepository.java  (interface)
│   └── exception/
│       └── DomainExceptions.java
│
├── application/
│   ├── port/
│   │   ├── input/
│   │   │   ├── OrderUseCases.java
│   │   │   ├── command/
│   │   │   │   └── CreateOrderCommand.java
│   │   │   └── query/
│   │   │       └── GetOrderQuery.java
│   │   └── output/
│   │       ├── PaymentGateway.java
│   │       ├── NotificationService.java
│   │       └── EventPublisher.java
│   ├── service/
│   │   ├── OrderCommandService.java
│   │   └── OrderQueryService.java
│   ├── eventhandler/
│   │   ├── SendConfirmationEmailHandler.java
│   │   └── ReserveInventoryHandler.java
│   ├── saga/
│   │   └── OrderPaymentSaga.java
│   └── dto/
│       └── OrderDTO.java
│
├── infrastructure/
│   ├── adapter/
│   │   ├── input/
│   │   │   ├── rest/
│   │   │   │   ├── OrderController.java
│   │   │   │   └── dto/
│   │   │   ├── graphql/
│   │   │   │   └── OrderResolver.java
│   │   │   └── cli/
│   │   │       └── OrderCLI.java
│   │   └── output/
│   │       ├── persistence/
│   │       │   ├── JpaOrderRepository.java
│   │       │   ├── entity/
│   │       │   │   └── OrderEntity.java
│   │       │   └── mapper/
│   │       │       └── OrderPersistenceMapper.java
│   │       ├── messaging/
│   │       │   └── RabbitMQEventPublisher.java
│   │       └── notification/
│   │           └── SendGridNotificationService.java
│   ├── acl/
│   │   └── stripe/
│   │       └── StripePaymentGateway.java
│   └── config/
│       ├── BeanConfiguration.java
│       └── RabbitMQConfiguration.java
│
└── OrdersApplication.java
```

---

# Conclusión

Arquitectura Hexagonal y Domain-Driven Design producen software que:

1. **Refleja el negocio**: El código habla el mismo idioma que los expertos
2. **Es mantenible**: Cada pieza tiene una responsabilidad clara
3. **Es testeable**: El dominio puede probarse sin infraestructura
4. **Es adaptable**: Puedes cambiar tecnologías sin reescribir el negocio

## Recordatorio final

- **DDD** → QUÉ construir (el modelo del negocio)
- **Arquitectura Hexagonal** → CÓMO organizarlo (la estructura)
- **SRP** → DÓNDE poner cada cosa (las responsabilidades)
- **Eventos** → CONECTAR las piezas sin acoplarlas

Empieza con lo básico:
1. Separa el dominio de la infraestructura
2. Usa Value Objects para conceptos importantes
3. Haz que las entidades tengan comportamiento
4. Agrega puertos y adaptadores cuando necesites flexibilidad
5. Introduce eventos cuando el acoplamiento crezca

**La arquitectura es un viaje, no un destino.**

---

*Documento generado como guía de referencia para desarrollo con Arquitectura Hexagonal y DDD en Java 21.*