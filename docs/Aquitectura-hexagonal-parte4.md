---

# 6. Principio de Responsabilidad Única (SRP)

## 6.1 ¿Qué es el Principio de Responsabilidad Única?

El Principio de Responsabilidad Única establece que **una clase debe tener una única razón para cambiar**.

### Problema: Clase con múltiples responsabilidades

```java
// ❌ MAL: Esta clase hace demasiadas cosas
public class Order {
    
    // Responsabilidad 1: Datos y reglas de negocio
    public void addItem(Product product, int quantity) { }
    public void confirm() { }
    
    // Responsabilidad 2: Persistencia (¿por qué sabe de JPA?)
    @Transactional
    public void saveToDatabase(EntityManager em) {
        em.persist(this);
    }
    
    // Responsabilidad 3: Notificaciones (¿por qué envía emails?)
    public void sendConfirmationEmail(JavaMailSender mailSender) {
        var message = mailSender.createMimeMessage();
        // ...
    }
    
    // Responsabilidad 4: Reportes
    public byte[] generateInvoicePDF() { }
}
```

### Solución: Separar responsabilidades

```java
// ✅ BIEN: Cada clase tiene UNA responsabilidad

// Responsabilidad: Reglas de negocio del pedido
public class Order {
    public void addItem(Product product, int quantity) { }
    public void confirm() { }
    public Money calculateTotal() { }
}

// Responsabilidad: Persistir pedidos
public interface OrderRepository {
    void save(Order order);
    Optional<Order> findById(OrderId id);
}

// Responsabilidad: Enviar notificaciones
public interface NotificationService {
    void sendOrderConfirmation(Order order);
}

// Responsabilidad: Generar documentos
public interface InvoiceGenerator {
    byte[] generatePDF(Order order);
}
```

## 6.2 Separación Command/Query (CQRS light)

```java
// application/service/OrderCommandService.java
// Responsabilidad: Ejecutar comandos (modificar estado)

@Service
@RequiredArgsConstructor
@Transactional
public class OrderCommandService implements OrderUseCases {
    
    private final OrderRepository orderRepository;
    private final ProductRepository productRepository;
    private final EventPublisher eventPublisher;

    @Override
    public OrderId createOrder(CreateOrderCommand command) {
        var order = Order.create(CustomerId.of(command.customerId()));
        
        for (var itemRequest : command.items()) {
            var product = productRepository.findById(ProductId.of(itemRequest.productId()))
                .orElseThrow(() -> new ProductNotFoundException(itemRequest.productId()));
            order.addItem(product, itemRequest.quantity());
        }
        
        orderRepository.save(order);
        eventPublisher.publishAll(order.pullDomainEvents());
        
        return order.getId();
    }

    @Override
    public void confirmOrder(ConfirmOrderCommand command) {
        var order = orderRepository.findById(OrderId.of(command.orderId()))
            .orElseThrow(() -> new OrderNotFoundException(command.orderId()));
        
        order.confirm();
        
        orderRepository.save(order);
        eventPublisher.publishAll(order.pullDomainEvents());
    }
}


// application/service/OrderQueryService.java
// Responsabilidad: Ejecutar queries (leer estado)

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class OrderQueryService {
    
    private final OrderRepository orderRepository;
    private final OrderDTOMapper mapper;

    public OrderDTO getOrder(GetOrderQuery query) {
        var order = orderRepository.findById(OrderId.of(query.orderId()))
            .orElseThrow(() -> new OrderNotFoundException(query.orderId()));
        return mapper.toDTO(order);
    }

    public List<OrderDTO> listCustomerOrders(ListOrdersQuery query) {
        return orderRepository.findByCustomer(CustomerId.of(query.customerId()))
            .stream()
            .map(mapper::toDTO)
            .toList();
    }

    public Page<OrderDTO> searchOrders(SearchOrdersQuery query, Pageable pageable) {
        // Usar especificaciones o criteria para búsqueda flexible
        return orderRepository.findAll(pageable)
            .map(mapper::toDTO);
    }
}
```

---

# 7. Arquitectura Orientada a Eventos

## 7.1 ¿Por qué eventos?

### El problema del acoplamiento

```java
// ❌ MAL: El servicio conoce TODO lo que debe pasar
@Service
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final EmailService emailService;
    private final InventoryService inventoryService;
    private final AnalyticsService analyticsService;
    private final LoyaltyService loyaltyService;
    
    public void confirmOrder(String orderId) {
        var order = orderRepository.findById(orderId);
        order.confirm();
        orderRepository.save(order);
        
        // El servicio conoce y coordina todo
        emailService.sendConfirmation(order);
        inventoryService.reserveStock(order);
        analyticsService.recordSale(order);
        loyaltyService.addPoints(order);
        // ¿Y si mañana agrego otra cosa?
    }
}
```

```java
// ✅ BIEN: El servicio solo confirma y publica
@Service
public class OrderCommandService {
    
    private final OrderRepository orderRepository;
    private final EventPublisher eventPublisher;
    
    public void confirmOrder(String orderId) {
        var order = orderRepository.findById(orderId);
        order.confirm();
        orderRepository.save(order);
        
        // Solo publicamos que algo ocurrió
        eventPublisher.publishAll(order.pullDomainEvents());
    }
}

// Cada handler reacciona independientemente
```

## 7.2 Event Handlers (Java 21)

```java
// application/eventhandler/SendOrderConfirmationEmailHandler.java

@Component
@RequiredArgsConstructor
@Slf4j
public class SendOrderConfirmationEmailHandler {
    
    private final NotificationService notificationService;
    private final CustomerRepository customerRepository;

    @EventListener
    @Async
    public void handle(OrderConfirmedEvent event) {
        log.info("Handling OrderConfirmedEvent for order {}", event.orderId());
        
        var customer = customerRepository.findById(event.customerId())
            .orElseThrow(() -> new CustomerNotFoundException(event.customerId().value()));
        
        notificationService.sendEmail(new EmailNotification(
            customer.getEmail(),
            "Order Confirmed - #" + event.orderId().value(),
            "order-confirmation",
            Map.of(
                "orderId", event.orderId().value(),
                "total", event.totalAmount().amount().toString(),
                "currency", event.totalAmount().currency().name(),
                "items", event.items()
            )
        ));
        
        log.info("Confirmation email sent for order {}", event.orderId());
    }
}


// application/eventhandler/ReserveInventoryHandler.java

@Component
@RequiredArgsConstructor
@Slf4j
public class ReserveInventoryHandler {
    
    private final InventoryService inventoryService;

    @EventListener
    @Async
    public void handle(OrderConfirmedEvent event) {
        log.info("Reserving inventory for order {}", event.orderId());
        
        var reservationItems = event.items().stream()
            .map(item -> new ReservationRequest.ReservationItem(
                item.productId(),
                item.quantity()
            ))
            .toList();
        
        var reservation = inventoryService.reserve(new ReservationRequest(
            event.orderId().value(),
            reservationItems
        ));
        
        log.info("Inventory reserved: {}", reservation.id());
    }
}


// application/eventhandler/UpdateSalesMetricsHandler.java

@Component
@RequiredArgsConstructor
@Slf4j
public class UpdateSalesMetricsHandler {
    
    private final MetricsService metricsService;

    @EventListener
    @Async
    public void handle(OrderConfirmedEvent event) {
        metricsService.recordSale(
            event.orderId().value(),
            event.totalAmount(),
            event.occurredOn()
        );
    }
}
```

---

# 8. Flujos de Aplicación Completos

## 8.1 Patrón Saga: Operaciones Distribuidas

### ¿Qué es una Saga?

Una Saga es un patrón para manejar transacciones que abarcan múltiples servicios. Usa una secuencia de transacciones locales con **compensaciones** si algo falla.

### Ejemplo: Saga de Pago de Pedido (Java 21)

```java
// application/saga/OrderPaymentSaga.java

@Component
@RequiredArgsConstructor
@Slf4j
public class OrderPaymentSaga {
    
    private final OrderRepository orderRepository;
    private final InventoryService inventoryService;
    private final PaymentGateway paymentGateway;
    private final EventPublisher eventPublisher;

    @Transactional
    public PaymentResult execute(OrderId orderId) {
        log.info("[Saga] Starting payment saga for order {}", orderId);
        
        var order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId.value()));
        
        // Variable para rastrear qué necesita compensación
        InventoryReservation inventoryReservation = null;
        
        try {
            // PASO 1: Reservar inventario
            log.info("[Saga] Step 1: Reserving inventory");
            inventoryReservation = reserveInventory(order);
            
            // PASO 2: Procesar pago
            log.info("[Saga] Step 2: Processing payment");
            var paymentResult = processPayment(order);
            
            if (!paymentResult.success()) {
                throw new PaymentFailedException(paymentResult.errorMessage());
            }
            
            // PASO 3: Confirmar reserva de inventario
            log.info("[Saga] Step 3: Confirming inventory reservation");
            inventoryService.confirmReservation(inventoryReservation.id());
            
            // PASO 4: Marcar pedido como pagado
            log.info("[Saga] Step 4: Marking order as paid");
            order.markAsPaid(paymentResult.transactionId());
            orderRepository.save(order);
            
            // Publicar evento de éxito
            eventPublisher.publish(new OrderPaidEvent(
                orderId,
                paymentResult.transactionId(),
                order.calculateTotal()
            ));
            
            log.info("[Saga] Completed successfully");
            return paymentResult;
            
        } catch (Exception e) {
            // COMPENSACIÓN
            log.error("[Saga] Error: {}. Starting compensation...", e.getMessage());
            compensate(order, inventoryReservation, e);
            throw e;
        }
    }
    
    private InventoryReservation reserveInventory(Order order) {
        var items = order.getItemsSummary().stream()
            .map(item -> new ReservationRequest.ReservationItem(
                item.productId(),
                item.quantity()
            ))
            .toList();
        
        return inventoryService.reserve(new ReservationRequest(
            order.getId().value(),
            items
        ));
    }
    
    private PaymentResult processPayment(Order order) {
        return paymentGateway.processPayment(new PaymentRequest(
            order.getId(),
            order.calculateTotal(),
            order.getCustomerId(),
            PaymentMethod.defaultCard()
        ));
    }
    
    private void compensate(Order order, InventoryReservation reservation, Exception cause) {
        // Liberar inventario si fue reservado
        if (reservation != null) {
            try {
                log.info("[Saga] Compensating: Releasing inventory reservation");
                inventoryService.releaseReservation(reservation.id());
            } catch (Exception e) {
                log.error("[Saga] Failed to release inventory: {}", e.getMessage());
            }
        }
        
        // Marcar pedido como fallido
        try {
            order.markPaymentFailed(cause.getMessage());
            orderRepository.save(order);
            
            eventPublisher.publish(new OrderPaymentFailedEvent(
                order.getId(),
                cause.getMessage()
            ));
        } catch (Exception e) {
            log.error("[Saga] Failed to mark order as failed: {}", e.getMessage());
        }
    }
}
```

---

# 9. Patrones Avanzados

## 9.1 Outbox Pattern

### El problema

Cuando guardas un agregado y publicas eventos, tienes dos operaciones que deben ser atómicas.

### La solución (Java 21)

```java
// infrastructure/adapter/output/persistence/TransactionalOrderRepository.java

@Repository
@RequiredArgsConstructor
public class TransactionalOrderRepository implements OrderRepository {
    
    private final JdbcTemplate jdbcTemplate;
    private final OrderPersistenceMapper mapper;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional
    public void save(Order order) {
        var events = order.pullDomainEvents();
        
        // Guardar el pedido
        saveOrder(order);
        
        // Guardar eventos en outbox (misma transacción)
        for (var event : events) {
            saveToOutbox(event);
        }
    }
    
    private void saveOrder(Order order) {
        jdbcTemplate.update("""
            INSERT INTO orders (id, customer_id, status, total_amount, total_currency, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT (id) DO UPDATE SET
                status = EXCLUDED.status,
                total_amount = EXCLUDED.total_amount,
                updated_at = NOW()
            """,
            order.getId().value(),
            order.getCustomerId().value(),
            order.getStatus().name(),
            order.calculateTotal().amount(),
            order.calculateTotal().currency().name(),
            order.getCreatedAt()
        );
    }
    
    private void saveToOutbox(DomainEvent event) {
        try {
            jdbcTemplate.update("""
                INSERT INTO outbox_messages 
                (id, aggregate_type, aggregate_id, event_type, payload, created_at)
                VALUES (?, ?, ?, ?, ?::jsonb, ?)
                """,
                event.eventId(),
                event.aggregateType(),
                event.aggregateId(),
                event.eventType(),
                objectMapper.writeValueAsString(event),
                event.occurredOn()
            );
        } catch (JsonProcessingException e) {
            throw new OutboxSerializationException(e);
        }
    }
}


// infrastructure/worker/OutboxWorker.java

@Component
@RequiredArgsConstructor
@Slf4j
public class OutboxWorker {
    
    private final JdbcTemplate jdbcTemplate;
    private final RabbitTemplate rabbitTemplate;

    @Scheduled(fixedRate = 1000)
    @Transactional
    public void processOutbox() {
        var messages = jdbcTemplate.query("""
            SELECT id, aggregate_type, event_type, payload 
            FROM outbox_messages 
            WHERE processed_at IS NULL 
            ORDER BY created_at 
            LIMIT 100
            FOR UPDATE SKIP LOCKED
            """,
            (rs, rowNum) -> new OutboxMessage(
                rs.getString("id"),
                rs.getString("aggregate_type"),
                rs.getString("event_type"),
                rs.getString("payload")
            )
        );
        
        for (var message : messages) {
            try {
                var exchange = "domain." + message.aggregateType().toLowerCase();
                rabbitTemplate.convertAndSend(exchange, message.eventType(), message.payload());
                
                jdbcTemplate.update(
                    "UPDATE outbox_messages SET processed_at = NOW() WHERE id = ?",
                    message.id()
                );
                
                log.debug("Processed outbox message {}", message.id());
            } catch (Exception e) {
                log.error("Failed to process outbox message {}: {}", message.id(), e.getMessage());
            }
        }
    }
    
    private record OutboxMessage(String id, String aggregateType, String eventType, String payload) {}
}
```

## 9.2 Specification Pattern (Java 21)

```java
// domain/specification/Specification.java

@FunctionalInterface
public interface Specification<T> {
    
    boolean isSatisfiedBy(T candidate);
    
    default Specification<T> and(Specification<T> other) {
        return candidate -> this.isSatisfiedBy(candidate) && other.isSatisfiedBy(candidate);
    }
    
    default Specification<T> or(Specification<T> other) {
        return candidate -> this.isSatisfiedBy(candidate) || other.isSatisfiedBy(candidate);
    }
    
    default Specification<T> not() {
        return candidate -> !this.isSatisfiedBy(candidate);
    }
}


// domain/specification/order/OrderSpecifications.java

public final class OrderSpecifications {
    
    private OrderSpecifications() {}
    
    public static Specification<Order> isConfirmed() {
        return order -> order.getStatus() == OrderStatus.CONFIRMED;
    }
    
    public static Specification<Order> isPending() {
        return order -> order.getStatus() == OrderStatus.PENDING;
    }
    
    public static Specification<Order> exceedsAmount(Money minimumAmount) {
        return order -> order.calculateTotal().isGreaterThan(minimumAmount);
    }
    
    public static Specification<Order> isRecent(int daysThreshold) {
        return order -> {
            var threshold = Instant.now().minus(daysThreshold, ChronoUnit.DAYS);
            return order.getCreatedAt().isAfter(threshold);
        };
    }
    
    public static Specification<Order> hasProduct(ProductId productId) {
        return order -> order.getItems().stream()
            .anyMatch(item -> item.getProductId().equals(productId));
    }
    
    public static Specification<Order> belongsToCustomer(CustomerId customerId) {
        return order -> order.getCustomerId().equals(customerId);
    }
    
    // Especificaciones compuestas
    public static Specification<Order> eligibleForFreeShipping() {
        return isConfirmed()
            .and(exceedsAmount(Money.of(100, Currency.USD)));
    }
    
    public static Specification<Order> eligibleForPrioritySupport() {
        return isConfirmed()
            .and(exceedsAmount(Money.of(500, Currency.USD)))
            .and(isRecent(30));
    }
}


// Uso
var eligibleOrders = allOrders.stream()
    .filter(OrderSpecifications.eligibleForFreeShipping()::isSatisfiedBy)
    .toList();

if (OrderSpecifications.eligibleForPrioritySupport().isSatisfiedBy(order)) {
    order.upgradeToPrioritySupport();
}
```

## 9.3 Anti-Corruption Layer (ACL) - Java 21

```java
// El dominio define lo que necesita (puerto)
// application/port/output/PaymentGateway.java

public interface PaymentGateway {
    PaymentResult processPayment(PaymentRequest request);
    RefundResult refund(String transactionId, Money amount);
}


// El ACL traduce entre Stripe y nuestro dominio
// infrastructure/acl/stripe/StripePaymentGateway.java

@Component
@RequiredArgsConstructor
@Slf4j
public class StripePaymentGateway implements PaymentGateway {
    
    private final StripeClient stripeClient;
    private final CustomerRepository customerRepository;

    @Override
    public PaymentResult processPayment(PaymentRequest request) {
        try {
            // Obtener Stripe Customer ID
            var customer = customerRepository.findById(request.customerId())
                .orElseThrow(() -> new CustomerNotFoundException(request.customerId().value()));
            
            var stripeCustomerId = customer.getStripeCustomerId()
                .orElseThrow(() -> new PaymentConfigurationException("Customer not configured for payments"));
            
            // Traducir de nuestro modelo a Stripe
            var params = PaymentIntentCreateParams.builder()
                .setAmount(toStripeCents(request.amount()))
                .setCurrency(request.amount().currency().name().toLowerCase())
                .setCustomer(stripeCustomerId)
                .setConfirm(true)
                .putMetadata("order_id", request.orderId().value())
                .putMetadata("source", "hexagonal-app")
                .build();
            
            // Llamar a Stripe
            var paymentIntent = stripeClient.paymentIntents().create(params);
            
            // Traducir respuesta de Stripe a nuestro modelo
            return mapToPaymentResult(paymentIntent);
            
        } catch (StripeException e) {
            // Traducir errores de Stripe a nuestro modelo
            return mapStripeError(e);
        }
    }
    
    @Override
    public RefundResult refund(String transactionId, Money amount) {
        try {
            var params = RefundCreateParams.builder()
                .setPaymentIntent(transactionId)
                .setAmount(toStripeCents(amount))
                .build();
            
            var refund = stripeClient.refunds().create(params);
            
            return new RefundResult(
                true,
                refund.getId(),
                null
            );
        } catch (StripeException e) {
            return new RefundResult(false, null, mapStripeErrorMessage(e));
        }
    }
    
    private long toStripeCents(Money money) {
        return money.amount().multiply(BigDecimal.valueOf(100)).longValue();
    }
    
    private PaymentResult mapToPaymentResult(PaymentIntent paymentIntent) {
        var success = "succeeded".equals(paymentIntent.getStatus());
        return new PaymentResult(
            success,
            paymentIntent.getId(),
            Instant.ofEpochSecond(paymentIntent.getCreated()),
            success ? null : "Payment status: " + paymentIntent.getStatus()
        );
    }
    
    private PaymentResult mapStripeError(StripeException e) {
        var message = switch (e) {
            case CardException ce -> "La tarjeta fue rechazada: " + ce.getDeclineCode();
            case InvalidRequestException ire -> "Datos de pago inválidos";
            case ApiException ae -> "Error temporal del servicio de pagos";
            default -> "Error procesando el pago";
        };
        
        log.error("Stripe error: {}", e.getMessage());
        return PaymentResult.failed(message);
    }
    
    private String mapStripeErrorMessage(StripeException e) {
        return switch (e) {
            case CardException ce -> "Refund failed: " + ce.getDeclineCode();
            case InvalidRequestException ire -> "Invalid refund request";
            default -> "Refund processing error";
        };
    }
}
```