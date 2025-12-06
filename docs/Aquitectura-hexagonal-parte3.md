---

# 4. Puertos: Los Contratos del Sistema

## 4.1 ¿Qué es un Puerto?

Un Puerto es una **interfaz** que define un contrato de comunicación. Es una abstracción que dice "qué se puede hacer" sin decir "cómo se hace".

Los puertos son el pegamento conceptual entre el interior y el exterior del hexágono.

## 4.2 Puertos Primarios (Driving Ports)

### ¿Qué son?

Los Puertos Primarios definen **cómo el mundo exterior puede usar nuestra aplicación**. Son los casos de uso que exponemos.

### Analogía

Piensa en el menú de un restaurante. El menú (puerto primario) te dice qué puedes pedir. No te dice cómo se cocina (implementación), solo qué opciones tienes.

### Ejemplo

```typescript
// application/ports/primary/OrderUseCases.ts

export interface OrderUseCases {
  // Comandos - modifican estado
  createOrder(command: CreateOrderCommand): Promise<OrderId>;
  addItemToOrder(command: AddItemCommand): Promise<void>;
  confirmOrder(command: ConfirmOrderCommand): Promise<void>;
  cancelOrder(command: CancelOrderCommand): Promise<void>;
  
  // Queries - solo leen
  getOrder(query: GetOrderQuery): Promise<OrderDTO>;
  listCustomerOrders(query: ListOrdersQuery): Promise<OrderDTO[]>;
}

export interface CreateOrderCommand {
  customerId: string;
  items: Array<{
    productId: string;
    quantity: number;
  }>;
  shippingAddress?: AddressDTO;
}
```

## 4.3 Puertos Secundarios (Driven Ports)

### ¿Qué son?

Los Puertos Secundarios definen **qué necesita nuestra aplicación del mundo exterior**. Son las dependencias que requerimos pero no queremos implementar directamente.

### Analogía

Piensa en un enchufe eléctrico. Tu computadora necesita electricidad, pero no le importa si viene de una planta nuclear, solar, o eólica. El enchufe (puerto secundario) define "necesito electricidad con estas características", no cómo se genera.

### Ejemplos

```typescript
// application/ports/secondary/OrderRepository.ts

export interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  delete(id: OrderId): Promise<void>;
  nextId(): OrderId;
}


// application/ports/secondary/PaymentGateway.ts

export interface PaymentGateway {
  processPayment(request: PaymentRequest): Promise<PaymentResult>;
  refund(transactionId: string, amount: Money): Promise<RefundResult>;
  getTransactionStatus(transactionId: string): Promise<TransactionStatus>;
}


// application/ports/secondary/NotificationService.ts

export interface NotificationService {
  sendEmail(notification: EmailNotification): Promise<void>;
  sendSMS(notification: SMSNotification): Promise<void>;
  sendPush(notification: PushNotification): Promise<void>;
}


// application/ports/secondary/EventPublisher.ts

export interface EventPublisher {
  publish(event: DomainEvent): Promise<void>;
  publishAll(events: DomainEvent[]): Promise<void>;
}
```

## 4.4 Puerto vs Adaptador: La Diferencia Clave

| Aspecto | Puerto | Adaptador |
|---------|--------|-----------|
| ¿Qué es? | Interface (contrato) | Clase (implementación) |
| ¿Dónde vive? | Dominio o Aplicación | Infraestructura |
| ¿Conoce tecnología? | No | Sí |
| ¿Cuántos puede haber? | Uno por concepto | Múltiples por puerto |

**Un puerto, múltiples adaptadores:**
```
Puerto: NotificationService
  ├── Adaptador: SendGridEmailService (producción)
  ├── Adaptador: SESEmailService (alternativa AWS)
  ├── Adaptador: ConsoleNotificationService (desarrollo)
  └── Adaptador: MockNotificationService (testing)
```

---

# 5. Adaptadores: Las Implementaciones Concretas

## 5.1 ¿Qué es un Adaptador?

Un Adaptador es una **implementación concreta de un puerto**. Traduce entre el lenguaje del dominio y el lenguaje de una tecnología específica.

### Analogía

Un adaptador de corriente convierte el voltaje de un país al que necesita tu dispositivo. De la misma forma, un adaptador de software convierte entre formatos: de JSON a objetos de dominio, de objetos de dominio a filas de base de datos, etc.

## 5.2 Adaptadores Primarios (Driving Adapters)

### ¿Qué son?

Reciben peticiones del exterior y las convierten en llamadas a los puertos primarios.

### Flujo

```
Usuario → [HTTP Request] → Adaptador REST → [Command/Query] → Puerto Primario → Aplicación
```

### Ejemplo: Adaptador REST

```typescript
// infrastructure/adapters/primary/rest/OrderController.ts

@Controller('orders')
export class OrderController {
  constructor(
    @Inject('OrderUseCases')
    private readonly orderUseCases: OrderUseCases
  ) {}

  @Post()
  @HttpCode(201)
  async createOrder(
    @Body() body: CreateOrderRequestDTO
  ): Promise<CreateOrderResponseDTO> {
    
    // 1. Traducir de HTTP a Command de dominio
    const command: CreateOrderCommand = {
      customerId: body.customer_id,  // snake_case → camelCase
      items: body.items.map(item => ({
        productId: item.product_id,
        quantity: item.qty
      })),
      shippingAddress: body.shipping_address 
        ? this.mapAddress(body.shipping_address)
        : undefined
    };

    // 2. Delegar al caso de uso
    const orderId = await this.orderUseCases.createOrder(command);

    // 3. Traducir respuesta a formato HTTP
    return {
      order_id: orderId.value,
      status: 'created',
      links: {
        self: `/orders/${orderId.value}`,
        confirm: `/orders/${orderId.value}/confirm`
      }
    };
  }

  @Get(':id')
  async getOrder(@Param('id') id: string): Promise<OrderResponseDTO> {
    const order = await this.orderUseCases.getOrder({ orderId: id });
    return this.mapToResponse(order);
  }

  @Post(':id/confirm')
  @HttpCode(200)
  async confirmOrder(@Param('id') id: string): Promise<void> {
    await this.orderUseCases.confirmOrder({ orderId: id });
  }
}
```

### Ejemplo: Adaptador CLI

```typescript
// infrastructure/adapters/primary/cli/OrderCLI.ts

export class OrderCLI {
  constructor(private readonly orderUseCases: OrderUseCases) {}

  async run(args: string[]): Promise<void> {
    const [command, ...params] = args;

    switch (command) {
      case 'create':
        await this.handleCreate(params);
        break;
      case 'confirm':
        await this.handleConfirm(params);
        break;
      case 'show':
        await this.handleShow(params);
        break;
      default:
        this.showHelp();
    }
  }

  private async handleCreate(params: string[]): Promise<void> {
    const customerId = params[0];
    const items = this.parseItems(params.slice(1));

    const orderId = await this.orderUseCases.createOrder({
      customerId,
      items
    });

    console.log(`✓ Pedido creado: ${orderId.value}`);
  }
}
```

**Observa**: Ambos adaptadores (REST y CLI) usan el MISMO puerto `OrderUseCases`. La lógica de negocio no sabe si la petición vino de HTTP o de la terminal.

## 5.3 Adaptadores Secundarios (Driven Adapters)

### ¿Qué son?

Implementan los puertos secundarios, conectando la aplicación con servicios externos como bases de datos, APIs, colas de mensajes, etc.

### Ejemplo: Adaptador de Persistencia (PostgreSQL)

```typescript
// infrastructure/adapters/secondary/persistence/PostgresOrderRepository.ts

export class PostgresOrderRepository implements OrderRepository {
  constructor(
    private readonly prisma: PrismaClient,
    private readonly mapper: OrderPersistenceMapper
  ) {}

  async save(order: Order): Promise<void> {
    const data = this.mapper.toPersistence(order);

    await this.prisma.$transaction(async (tx) => {
      await tx.order.upsert({
        where: { id: data.id },
        update: {
          status: data.status,
          total: data.total,
          updatedAt: new Date()
        },
        create: {
          id: data.id,
          customerId: data.customerId,
          status: data.status,
          total: data.total,
          createdAt: data.createdAt
        }
      });

      // Sincronizar items
      await tx.orderItem.deleteMany({ where: { orderId: data.id } });
      await tx.orderItem.createMany({ data: data.items });
    });
  }

  async findById(id: OrderId): Promise<Order | null> {
    const data = await this.prisma.order.findUnique({
      where: { id: id.value },
      include: { items: true }
    });

    if (!data) return null;
    return this.mapper.toDomain(data);
  }
}
```

### El Mapper: Traductor entre mundos

```typescript
// infrastructure/adapters/secondary/persistence/OrderPersistenceMapper.ts

export class OrderPersistenceMapper {
  
  // Dominio → Persistencia
  toPersistence(order: Order): OrderPersistenceModel {
    return {
      id: order.id.value,
      customerId: order.customerId.value,
      status: order.status,
      total: order.total.getAmount(),
      currency: order.total.getCurrency(),
      createdAt: order.createdAt,
      items: order.getItemsSummary().map(item => ({
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        unitPrice: item.unitPrice
      }))
    };
  }

  // Persistencia → Dominio
  toDomain(data: OrderWithItems): Order {
    const items = data.items.map(item => 
      OrderItem.reconstitute(
        ProductId.from(item.productId),
        item.productName,
        Money.of(item.unitPrice, data.currency as Currency),
        item.quantity
      )
    );

    return Order.reconstitute(
      OrderId.from(data.id),
      CustomerId.from(data.customerId),
      items,
      data.status as OrderStatus,
      new Date(data.createdAt)
    );
  }
}
```

### Ejemplo: Adaptador de Mensajería (RabbitMQ)

```typescript
// infrastructure/adapters/secondary/messaging/RabbitMQEventPublisher.ts

export class RabbitMQEventPublisher implements EventPublisher {
  constructor(
    private readonly connection: Connection,
    private readonly serializer: EventSerializer
  ) {}

  async publish(event: DomainEvent): Promise<void> {
    const channel = await this.connection.createChannel();
    
    try {
      const exchange = `domain.${event.aggregateType.toLowerCase()}`;
      const routingKey = event.eventType;
      const message = this.serializer.serialize(event);

      await channel.assertExchange(exchange, 'topic', { durable: true });

      channel.publish(
        exchange,
        routingKey,
        Buffer.from(message),
        {
          persistent: true,
          messageId: event.eventId,
          timestamp: event.occurredOn.getTime(),
          contentType: 'application/json'
        }
      );
    } finally {
      await channel.close();
    }
  }
}
```

---

# 6. Principio de Responsabilidad Única (SRP)

## 6.1 ¿Qué es el Principio de Responsabilidad Única?

El Principio de Responsabilidad Única (SRP) establece que **una clase debe tener una única razón para cambiar**. En otras palabras, cada clase debe hacer una sola cosa y hacerla bien.

### La definición de Robert C. Martin

> "Una clase debe tener uno, y solo uno, motivo para cambiar."

### ¿Qué es una "responsabilidad"?

Una responsabilidad es un **eje de cambio**. Si puedes pensar en más de una razón por la que una clase podría necesitar modificarse, tiene más de una responsabilidad.

## 6.2 SRP en el Dominio

### Problema: Clase con múltiples responsabilidades

```typescript
// ❌ MAL: Esta clase hace demasiadas cosas
class Order {
  // Responsabilidad 1: Datos y reglas de negocio
  addItem(product: Product, quantity: number): void { }
  confirm(): void { }
  
  // Responsabilidad 2: Persistencia (¿por qué el pedido sabe de SQL?)
  async saveToDatabase(connection: DBConnection): Promise<void> {
    await connection.query('INSERT INTO orders...');
  }
  
  // Responsabilidad 3: Notificaciones (¿por qué envía emails?)
  async sendConfirmationEmail(emailService: EmailService): Promise<void> {
    await emailService.send(this.customerEmail, 'Pedido confirmado');
  }
  
  // Responsabilidad 4: Reportes
  generateInvoicePDF(): Buffer { }
}
```

**Problemas:**
- Si cambia la BD, hay que modificar `Order`
- Si cambia el proveedor de email, hay que modificar `Order`
- Testear es difícil: necesitas mockear DB, email, PDF
- Un bug en facturación puede romper la lógica de pedidos

### Solución: Separar responsabilidades

```typescript
// ✅ BIEN: Cada clase tiene UNA responsabilidad

// Responsabilidad: Reglas de negocio del pedido
class Order {
  addItem(product: Product, quantity: number): void { }
  confirm(): OrderConfirmedEvent { }
  total(): Money { }
}

// Responsabilidad: Persistir pedidos
class OrderRepository {
  async save(order: Order): Promise<void> { }
  async findById(id: OrderId): Promise<Order | null> { }
}

// Responsabilidad: Enviar notificaciones de pedidos
class OrderNotificationService {
  async sendConfirmation(order: Order): Promise<void> { }
}

// Responsabilidad: Generar documentos de pedidos
class OrderDocumentGenerator {
  generateInvoice(order: Order): Buffer { }
}
```

## 6.3 Separación Command/Query (CQRS light)

Una aplicación muy efectiva de SRP es separar las operaciones de escritura de las de lectura.

```typescript
// Responsabilidad: Ejecutar comandos (modificar estado)
class OrderCommandService {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly eventPublisher: EventPublisher
  ) {}

  async createOrder(command: CreateOrderCommand): Promise<OrderId> { }
  async confirmOrder(command: ConfirmOrderCommand): Promise<void> { }
}

// Responsabilidad: Ejecutar queries (leer estado)
class OrderQueryService {
  constructor(private readonly orderReadRepository: OrderReadRepository) {}

  async getOrder(query: GetOrderQuery): Promise<OrderDTO> { }
  async listOrders(query: ListOrdersQuery): Promise<PaginatedResult<OrderDTO>> { }
}
```

**Beneficios:**
- Los comandos y queries pueden escalar independientemente
- Los queries pueden usar bases de datos optimizadas para lectura
- Más fácil de testear y razonar

## 6.4 SRP en Event Handlers

Cada handler tiene una única responsabilidad: reaccionar a un evento de una forma específica.

```typescript
// Responsabilidad: Enviar email de confirmación
class SendOrderConfirmationEmailHandler {
  async handle(event: OrderConfirmedEvent): Promise<void> {
    await this.notificationService.sendEmail({
      to: event.customerEmail,
      templateId: 'order-confirmed',
      data: { orderId: event.aggregateId }
    });
  }
}

// Responsabilidad: Reservar inventario
class ReserveInventoryHandler {
  async handle(event: OrderConfirmedEvent): Promise<void> {
    await this.inventoryService.reserve({
      orderId: event.aggregateId,
      items: event.items
    });
  }
}

// Responsabilidad: Actualizar métricas
class UpdateSalesMetricsHandler {
  async handle(event: OrderConfirmedEvent): Promise<void> {
    await this.analyticsService.recordSale({
      orderId: event.aggregateId,
      amount: event.totalAmount
    });
  }
}
```

**¿Por qué no un solo handler?**

```typescript
// ❌ MAL: Un handler con múltiples responsabilidades
class OrderConfirmedMegaHandler {
  async handle(event: OrderConfirmedEvent): Promise<void> {
    await this.sendEmail(event);        // Si falla, ¿qué pasa?
    await this.reserveInventory(event); // ¿Se reservó o no?
    await this.updateMetrics(event);    // Todo junto o nada
  }
}
```

**Problemas:**
- Si falla uno, fallan todos
- No puedes reintentar uno sin reintentar todos
- No puedes ejecutar algunos en paralelo