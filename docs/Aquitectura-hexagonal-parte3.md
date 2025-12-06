---

# 4. Puertos: Los Contratos del Sistema

## 4.1 ¿Qué es un Puerto?

Un Puerto es una **interfaz** que define un contrato de comunicación. Es una abstracción que dice "qué se puede hacer" sin decir "cómo se hace".

## 4.2 Puertos Primarios (Driving Ports)

### ¿Qué son?

Los Puertos Primarios definen **cómo el mundo exterior puede usar nuestra aplicación**. Son los casos de uso que exponemos.

### Ejemplo (Java 21)

```java
// application/port/input/OrderUseCases.java

public interface OrderUseCases {
    
    // Comandos - modifican estado
    OrderId createOrder(CreateOrderCommand command);
    void addItemToOrder(AddItemCommand command);
    void confirmOrder(ConfirmOrderCommand command);
    void cancelOrder(CancelOrderCommand command);
    
    // Queries - solo leen
    OrderDTO getOrder(GetOrderQuery query);
    List<OrderDTO> listCustomerOrders(ListOrdersQuery query);
    Page<OrderDTO> searchOrders(SearchOrdersQuery query, Pageable pageable);
}


// application/port/input/command/CreateOrderCommand.java

public record CreateOrderCommand(
    String customerId,
    List<OrderItemRequest> items,
    AddressRequest shippingAddress
) {
    public record OrderItemRequest(String productId, int quantity) {}
    public record AddressRequest(String street, String city, String state, 
                                  String zipCode, String country) {}
}


// application/port/input/command/ConfirmOrderCommand.java

public record ConfirmOrderCommand(String orderId) {}


// application/port/input/query/GetOrderQuery.java

public record GetOrderQuery(String orderId) {}
```

## 4.3 Puertos Secundarios (Driven Ports)

### ¿Qué son?

Los Puertos Secundarios definen **qué necesita nuestra aplicación del mundo exterior**.

### Ejemplos (Java 21)

```java
// application/port/output/PaymentGateway.java

public interface PaymentGateway {
    
    PaymentResult processPayment(PaymentRequest request);
    RefundResult refund(String transactionId, Money amount);
    PaymentStatus getTransactionStatus(String transactionId);
}

public record PaymentRequest(
    OrderId orderId,
    Money amount,
    CustomerId customerId,
    PaymentMethod paymentMethod
) {}

public record PaymentResult(
    boolean success,
    String transactionId,
    Instant processedAt,
    String errorMessage
) {
    public static PaymentResult successful(String transactionId) {
        return new PaymentResult(true, transactionId, Instant.now(), null);
    }
    
    public static PaymentResult failed(String errorMessage) {
        return new PaymentResult(false, null, Instant.now(), errorMessage);
    }
}


// application/port/output/NotificationService.java

public interface NotificationService {
    
    void sendEmail(EmailNotification notification);
    void sendSMS(SMSNotification notification);
    void sendPush(PushNotification notification);
}

public record EmailNotification(
    Email to,
    String subject,
    String templateId,
    Map<String, Object> data
) {}


// application/port/output/EventPublisher.java

public interface EventPublisher {
    
    void publish(DomainEvent event);
    void publishAll(List<DomainEvent> events);
}


// application/port/output/InventoryService.java

public interface InventoryService {
    
    InventoryReservation reserve(ReservationRequest request);
    void confirmReservation(String reservationId);
    void releaseReservation(String reservationId);
    boolean checkAvailability(ProductId productId, int quantity);
}

public record ReservationRequest(
    String orderId,
    List<ReservationItem> items
) {
    public record ReservationItem(String productId, int quantity) {}
}

public record InventoryReservation(
    String id,
    String orderId,
    Instant expiresAt,
    List<ReservationItem> items
) {}
```

---

# 5. Adaptadores: Las Implementaciones Concretas

## 5.1 ¿Qué es un Adaptador?

Un Adaptador es una **implementación concreta de un puerto**. Traduce entre el lenguaje del dominio y el lenguaje de una tecnología específica.

## 5.2 Adaptadores Primarios (Driving Adapters)

### Ejemplo: Adaptador REST con Spring Boot

```java
// infrastructure/adapter/input/rest/OrderController.java

@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {
    
    private final OrderUseCases orderUseCases;
    private final OrderDTOMapper mapper;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CreateOrderResponse createOrder(@Valid @RequestBody CreateOrderRequest request) {
        
        // 1. Traducir de HTTP Request a Command
        var command = new CreateOrderCommand(
            request.customerId(),
            request.items().stream()
                .map(item -> new CreateOrderCommand.OrderItemRequest(
                    item.productId(), 
                    item.quantity()
                ))
                .toList(),
            request.shippingAddress() != null 
                ? mapAddress(request.shippingAddress()) 
                : null
        );

        // 2. Delegar al caso de uso
        var orderId = orderUseCases.createOrder(command);

        // 3. Traducir respuesta a formato HTTP
        return new CreateOrderResponse(
            orderId.value(),
            "created",
            Map.of(
                "self", "/api/v1/orders/" + orderId.value(),
                "confirm", "/api/v1/orders/" + orderId.value() + "/confirm"
            )
        );
    }

    @GetMapping("/{orderId}")
    public OrderResponse getOrder(@PathVariable String orderId) {
        var query = new GetOrderQuery(orderId);
        var order = orderUseCases.getOrder(query);
        return mapper.toResponse(order);
    }

    @PostMapping("/{orderId}/confirm")
    @ResponseStatus(HttpStatus.OK)
    public void confirmOrder(@PathVariable String orderId) {
        orderUseCases.confirmOrder(new ConfirmOrderCommand(orderId));
    }

    @PostMapping("/{orderId}/cancel")
    @ResponseStatus(HttpStatus.OK)
    public void cancelOrder(
            @PathVariable String orderId,
            @RequestBody CancelOrderRequest request) {
        orderUseCases.cancelOrder(new CancelOrderCommand(orderId, request.reason()));
    }

    @GetMapping
    public Page<OrderResponse> searchOrders(
            @RequestParam(required = false) String customerId,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        
        var query = new SearchOrdersQuery(customerId, status);
        var pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        
        return orderUseCases.searchOrders(query, pageable)
            .map(mapper::toResponse);
    }

    private CreateOrderCommand.AddressRequest mapAddress(AddressRequest address) {
        return new CreateOrderCommand.AddressRequest(
            address.street(),
            address.city(),
            address.state(),
            address.zipCode(),
            address.country()
        );
    }
}


// infrastructure/adapter/input/rest/dto/CreateOrderRequest.java

public record CreateOrderRequest(
    @NotBlank String customerId,
    @NotEmpty List<OrderItemRequest> items,
    AddressRequest shippingAddress
) {
    public record OrderItemRequest(
        @NotBlank String productId,
        @Min(1) int quantity
    ) {}
    
    public record AddressRequest(
        @NotBlank String street,
        @NotBlank String city,
        String state,
        String zipCode,
        @NotBlank String country
    ) {}
}

public record CreateOrderResponse(
    String orderId,
    String status,
    Map<String, String> links
) {}

public record OrderResponse(
    String id,
    String customerId,
    String status,
    List<OrderItemResponse> items,
    MoneyResponse total,
    Instant createdAt
) {
    public record OrderItemResponse(
        String productId,
        String productName,
        int quantity,
        MoneyResponse unitPrice,
        MoneyResponse subtotal
    ) {}
    
    public record MoneyResponse(BigDecimal amount, String currency) {}
}
```

### Ejemplo: Adaptador CLI

```java
// infrastructure/adapter/input/cli/OrderCLI.java

@Component
@RequiredArgsConstructor
public class OrderCLI implements CommandLineRunner {
    
    private final OrderUseCases orderUseCases;
    private final ObjectMapper objectMapper;

    @Override
    public void run(String... args) throws Exception {
        if (args.length == 0) return;
        
        var command = args[0];
        var params = Arrays.copyOfRange(args, 1, args.length);

        switch (command) {
            case "order:create" -> handleCreate(params);
            case "order:confirm" -> handleConfirm(params);
            case "order:show" -> handleShow(params);
            case "order:list" -> handleList(params);
            default -> showHelp();
        }
    }

    private void handleCreate(String[] params) {
        if (params.length < 2) {
            System.err.println("Usage: order:create <customerId> <productId:quantity>...");
            return;
        }

        var customerId = params[0];
        var items = Arrays.stream(params)
            .skip(1)
            .map(this::parseItem)
            .toList();

        var command = new CreateOrderCommand(customerId, items, null);
        var orderId = orderUseCases.createOrder(command);

        System.out.println("✓ Order created: " + orderId.value());
    }

    private void handleConfirm(String[] params) {
        if (params.length < 1) {
            System.err.println("Usage: order:confirm <orderId>");
            return;
        }

        orderUseCases.confirmOrder(new ConfirmOrderCommand(params[0]));
        System.out.println("✓ Order confirmed");
    }

    private void handleShow(String[] params) throws Exception {
        if (params.length < 1) {
            System.err.println("Usage: order:show <orderId>");
            return;
        }

        var order = orderUseCases.getOrder(new GetOrderQuery(params[0]));
        System.out.println(objectMapper.writerWithDefaultPrettyPrinter()
            .writeValueAsString(order));
    }

    private CreateOrderCommand.OrderItemRequest parseItem(String itemStr) {
        var parts = itemStr.split(":");
        return new CreateOrderCommand.OrderItemRequest(parts[0], Integer.parseInt(parts[1]));
    }
}
```

## 5.3 Adaptadores Secundarios (Driven Adapters)

### Ejemplo: Adaptador de Persistencia con JPA

```java
// infrastructure/adapter/output/persistence/JpaOrderRepository.java

@Repository
@RequiredArgsConstructor
public class JpaOrderRepository implements OrderRepository {
    
    private final SpringDataOrderRepository springDataRepository;
    private final OrderPersistenceMapper mapper;

    @Override
    @Transactional
    public void save(Order order) {
        var entity = mapper.toEntity(order);
        springDataRepository.save(entity);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Order> findById(OrderId id) {
        return springDataRepository.findById(id.value())
            .map(mapper::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Order> findByCustomer(CustomerId customerId) {
        return springDataRepository.findByCustomerId(customerId.value())
            .stream()
            .map(mapper::toDomain)
            .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<Order> findByStatus(OrderStatus status) {
        return springDataRepository.findByStatus(status.name())
            .stream()
            .map(mapper::toDomain)
            .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public Page<Order> findAll(Pageable pageable) {
        return springDataRepository.findAll(pageable)
            .map(mapper::toDomain);
    }

    @Override
    public void delete(OrderId id) {
        springDataRepository.deleteById(id.value());
    }

    @Override
    public OrderId nextId() {
        return OrderId.generate();
    }

    @Override
    public boolean existsById(OrderId id) {
        return springDataRepository.existsById(id.value());
    }
}


// infrastructure/adapter/output/persistence/entity/OrderEntity.java

@Entity
@Table(name = "orders")
@Getter @Setter
@NoArgsConstructor
public class OrderEntity {
    
    @Id
    private String id;
    
    @Column(name = "customer_id", nullable = false)
    private String customerId;
    
    @Column(nullable = false)
    @Enumerated(EnumType.STRING)
    private OrderStatusEntity status;
    
    @Column(name = "total_amount", precision = 19, scale = 4)
    private BigDecimal totalAmount;
    
    @Column(name = "total_currency", length = 3)
    private String totalCurrency;
    
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
    
    @Column(name = "updated_at")
    private Instant updatedAt;
    
    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItemEntity> items = new ArrayList<>();
    
    @Version
    private Long version;
    
    @PrePersist
    void prePersist() {
        createdAt = Instant.now();
    }
    
    @PreUpdate
    void preUpdate() {
        updatedAt = Instant.now();
    }
}


// infrastructure/adapter/output/persistence/mapper/OrderPersistenceMapper.java

@Component
public class OrderPersistenceMapper {
    
    public OrderEntity toEntity(Order order) {
        var entity = new OrderEntity();
        entity.setId(order.getId().value());
        entity.setCustomerId(order.getCustomerId().value());
        entity.setStatus(OrderStatusEntity.valueOf(order.getStatus().name()));
        entity.setTotalAmount(order.calculateTotal().amount());
        entity.setTotalCurrency(order.calculateTotal().currency().name());
        entity.setCreatedAt(order.getCreatedAt());
        
        var itemEntities = order.getItems().stream()
            .map(item -> toItemEntity(item, entity))
            .toList();
        entity.setItems(new ArrayList<>(itemEntities));
        
        return entity;
    }
    
    public Order toDomain(OrderEntity entity) {
        var items = entity.getItems().stream()
            .map(this::toItemDomain)
            .toList();
        
        return Order.reconstitute(
            OrderId.of(entity.getId()),
            CustomerId.of(entity.getCustomerId()),
            items,
            OrderStatus.valueOf(entity.getStatus().name()),
            entity.getCreatedAt()
        );
    }
    
    private OrderItemEntity toItemEntity(OrderItem item, OrderEntity order) {
        var entity = new OrderItemEntity();
        entity.setOrder(order);
        entity.setProductId(item.getProductId().value());
        entity.setProductName(item.getProductName());
        entity.setQuantity(item.getQuantity());
        entity.setUnitPrice(item.getUnitPrice().amount());
        entity.setUnitCurrency(item.getUnitPrice().currency().name());
        return entity;
    }
    
    private OrderItem toItemDomain(OrderItemEntity entity) {
        return OrderItem.reconstitute(
            ProductId.of(entity.getProductId()),
            entity.getProductName(),
            Money.of(entity.getUnitPrice(), Currency.valueOf(entity.getUnitCurrency())),
            entity.getQuantity()
        );
    }
}
```

### Ejemplo: Adaptador de Mensajería con RabbitMQ

```java
// infrastructure/adapter/output/messaging/RabbitMQEventPublisher.java

@Component
@RequiredArgsConstructor
@Slf4j
public class RabbitMQEventPublisher implements EventPublisher {
    
    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;

    @Override
    public void publish(DomainEvent event) {
        try {
            var exchange = "domain." + event.aggregateType().toLowerCase();
            var routingKey = event.eventType();
            var message = objectMapper.writeValueAsString(event);
            
            rabbitTemplate.convertAndSend(
                exchange,
                routingKey,
                message,
                msg -> {
                    msg.getMessageProperties().setMessageId(event.eventId());
                    msg.getMessageProperties().setTimestamp(Date.from(event.occurredOn()));
                    msg.getMessageProperties().setContentType("application/json");
                    return msg;
                }
            );
            
            log.info("Published event {} to {}/{}", event.eventId(), exchange, routingKey);
            
        } catch (JsonProcessingException e) {
            throw new EventPublishingException("Failed to serialize event", e);
        }
    }

    @Override
    public void publishAll(List<DomainEvent> events) {
        events.forEach(this::publish);
    }
}


// infrastructure/adapter/output/messaging/InMemoryEventPublisher.java (para desarrollo)

@Component
@Profile("dev")
@Slf4j
public class InMemoryEventPublisher implements EventPublisher {
    
    private final ApplicationEventPublisher applicationEventPublisher;
    
    public InMemoryEventPublisher(ApplicationEventPublisher publisher) {
        this.applicationEventPublisher = publisher;
    }

    @Override
    public void publish(DomainEvent event) {
        log.info("Publishing event in-memory: {}", event.eventType());
        applicationEventPublisher.publishEvent(event);
    }

    @Override
    public void publishAll(List<DomainEvent> events) {
        events.forEach(this::publish);
    }
}
```

### Ejemplo: Adaptador de Notificaciones con SendGrid

```java
// infrastructure/adapter/output/notification/SendGridNotificationService.java

@Component
@RequiredArgsConstructor
@Slf4j
public class SendGridNotificationService implements NotificationService {
    
    private final SendGrid sendGridClient;
    private final TemplateEngine templateEngine;
    private final NotificationProperties properties;

    @Override
    public void sendEmail(EmailNotification notification) {
        try {
            var from = new com.sendgrid.helpers.mail.objects.Email(properties.getFromEmail());
            var to = new com.sendgrid.helpers.mail.objects.Email(notification.to().value());
            
            // Renderizar template
            var content = renderTemplate(notification.templateId(), notification.data());
            
            var mail = new Mail(from, notification.subject(), to, 
                new Content("text/html", content));
            
            var request = new Request();
            request.setMethod(Method.POST);
            request.setEndpoint("mail/send");
            request.setBody(mail.build());
            
            var response = sendGridClient.api(request);
            
            if (response.getStatusCode() >= 400) {
                throw new NotificationException("SendGrid error: " + response.getBody());
            }
            
            log.info("Email sent to {}", notification.to().value());
            
        } catch (IOException e) {
            throw new NotificationException("Failed to send email", e);
        }
    }

    @Override
    public void sendSMS(SMSNotification notification) {
        // Implementación con Twilio u otro proveedor
        log.warn("SMS sending not implemented yet");
    }

    @Override
    public void sendPush(PushNotification notification) {
        // Implementación con Firebase o similar
        log.warn("Push notification not implemented yet");
    }

    private String renderTemplate(String templateId, Map<String, Object> data) {
        var context = new Context();
        context.setVariables(data);
        return templateEngine.process(templateId, context);
    }
}
```