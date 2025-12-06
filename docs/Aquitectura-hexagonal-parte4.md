---

# 7. Arquitectura Orientada a Eventos

## 7.1 ¿Por qué eventos?

### El problema del acoplamiento temporal

Imagina este flujo cuando se confirma un pedido:

1. Actualizar estado del pedido
2. Reservar inventario
3. Procesar pago
4. Enviar email de confirmación
5. Notificar al almacén
6. Actualizar dashboard de ventas

**Enfoque sincrónico (sin eventos):**
- El usuario espera mientras todo esto ocurre
- Si falla el paso 5, ¿qué pasa con los pasos 1-4?
- Si el email está lento, todo es lento
- Si agregamos un paso 7, hay que modificar código existente

**Enfoque con eventos:**
- El pedido se confirma y se publica un evento
- Cada sistema reacciona de forma independiente
- Si el email falla, el pedido ya está confirmado
- Agregar comportamientos = agregar handlers

## 7.2 Implementación de un Sistema de Eventos

### Event Bus (Puerto)

```typescript
// application/ports/secondary/EventBus.ts

export interface EventBus {
  publish(event: DomainEvent): Promise<void>;
  publishAll(events: DomainEvent[]): Promise<void>;
  subscribe<T extends DomainEvent>(
    eventType: string,
    handler: EventHandler<T>
  ): void;
}

export interface EventHandler<T extends DomainEvent> {
  handle(event: T): Promise<void>;
}
```

### Agregado que produce eventos

```typescript
export class Order {
  private domainEvents: DomainEvent[] = [];

  static create(customerId: CustomerId): Order {
    const order = new Order(/* ... */);
    
    order.recordEvent(new OrderCreatedEvent(
      order.id.value,
      customerId.value
    ));
    
    return order;
  }

  confirm(): void {
    this.validateCanBeConfirmed();
    this.status = OrderStatus.CONFIRMED;
    
    this.recordEvent(new OrderConfirmedEvent(
      this.id.value,
      this.customerId.value,
      this.total().getAmount(),
      this.getItemsSummary()
    ));
  }

  protected recordEvent(event: DomainEvent): void {
    this.domainEvents.push(event);
  }

  pullDomainEvents(): DomainEvent[] {
    const events = [...this.domainEvents];
    this.domainEvents = [];
    return events;
  }
}
```

### Servicio de aplicación usando eventos

```typescript
export class OrderCommandService {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly eventBus: EventBus
  ) {}

  async confirmOrder(command: ConfirmOrderCommand): Promise<void> {
    const order = await this.orderRepository.findById(
      OrderId.from(command.orderId)
    );
    
    if (!order) {
      throw new OrderNotFoundError(command.orderId);
    }

    order.confirm();
    await this.orderRepository.save(order);

    // Los handlers reaccionarán
    const events = order.pullDomainEvents();
    await this.eventBus.publishAll(events);
  }
}
```

### Event Handlers

```typescript
export class SendConfirmationEmailHandler implements EventHandler<OrderConfirmedEvent> {
  constructor(private readonly notificationService: NotificationService) {}

  async handle(event: OrderConfirmedEvent): Promise<void> {
    await this.notificationService.sendEmail({
      to: event.customerEmail,
      subject: `Pedido ${event.aggregateId} confirmado`,
      templateId: 'order-confirmation',
      data: { orderId: event.aggregateId, total: event.totalAmount }
    });
  }
}

export class ReserveInventoryHandler implements EventHandler<OrderConfirmedEvent> {
  constructor(private readonly inventoryService: InventoryService) {}

  async handle(event: OrderConfirmedEvent): Promise<void> {
    for (const item of event.items) {
      await this.inventoryService.reserve({
        productId: item.productId,
        quantity: item.quantity,
        orderId: event.aggregateId
      });
    }
  }
}
```

---

# 8. Flujos de Aplicación Completos

## 8.1 Flujo: Crear y Confirmar un Pedido

### Diagrama del flujo

```
┌──────────┐     HTTP POST      ┌────────────────┐
│  Usuario │ ────────────────▶  │ REST Controller│
└──────────┘                    │  (Adaptador)   │
                                └───────┬────────┘
                                        │
                                        ▼ CreateOrderCommand
                                ┌───────────────────┐
                                │  OrderService     │
                                │  (Aplicación)     │
                                └───────┬───────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
            ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
            │ ProductRepo  │   │    Order     │   │  OrderRepo   │
            │ (findById)   │   │  (Dominio)   │   │   (save)     │
            └──────────────┘   └──────────────┘   └──────────────┘
                                        │
                                        ▼ OrderCreatedEvent
                                ┌───────────────────┐
                                │    Event Bus      │
                                └───────┬───────────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
            ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
            │ EmailHandler │   │ Analytics    │   │   Logging    │
            └──────────────┘   └──────────────┘   └──────────────┘
```

## 8.2 Patrón Saga: Operaciones Distribuidas

### ¿Qué es una Saga?

Una Saga es un patrón para manejar transacciones que abarcan múltiples servicios o agregados. En lugar de una transacción ACID tradicional, usa una secuencia de transacciones locales con **compensaciones** si algo falla.

### ¿Cuándo usar Sagas?

Cuando una operación de negocio:
- Involucra múltiples agregados
- Involucra servicios externos (pagos, inventario)
- No puede ejecutarse en una única transacción
- Necesita garantías de consistencia eventual

### El concepto de compensación

La compensación es la acción que "deshace" un paso anterior. No es un rollback técnico (eso sería una transacción), sino una operación de negocio que revierte el efecto.

**Ejemplo:**
- Paso: "Reservar inventario"
- Compensación: "Liberar inventario reservado"

### Ejemplo: Saga de Pago de Pedido

Imagina el proceso de pagar un pedido:

```
Flujo exitoso:
[Reservar Inventario] ✓ → [Procesar Pago] ✓ → [Confirmar Reserva] ✓ → [Marcar Pagado] ✓

Flujo con fallo y compensación:
[Reservar Inventario] ✓ → [Procesar Pago] ✗ → [COMPENSAR: Liberar Inventario]
```

### Implementación

```typescript
export class OrderPaymentSaga {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly inventoryService: InventoryService,
    private readonly paymentGateway: PaymentGateway,
    private readonly eventBus: EventBus
  ) {}

  async execute(orderId: OrderId): Promise<PaymentResult> {
    const order = await this.orderRepository.findById(orderId);
    if (!order) {
      throw new OrderNotFoundError(orderId.value);
    }

    // Variable para rastrear qué necesita compensación
    let inventoryReservation: InventoryReservation | null = null;

    try {
      // PASO 1: Reservar inventario
      console.log(`[Saga] Paso 1: Reservando inventario`);
      inventoryReservation = await this.inventoryService.reserve({
        orderId: orderId.value,
        items: order.getItemsSummary()
      });

      // PASO 2: Procesar pago
      console.log(`[Saga] Paso 2: Procesando pago`);
      const paymentResult = await this.paymentGateway.processPayment({
        orderId: orderId.value,
        amount: order.total().getAmount(),
        currency: order.total().getCurrency(),
        customerId: order.customerId.value
      });

      if (!paymentResult.success) {
        throw new PaymentFailedError(paymentResult.errorMessage);
      }

      // PASO 3: Confirmar reserva de inventario
      console.log(`[Saga] Paso 3: Confirmando reserva`);
      await this.inventoryService.confirmReservation(inventoryReservation.id);

      // PASO 4: Marcar pedido como pagado
      console.log(`[Saga] Paso 4: Marcando como pagado`);
      order.markAsPaid(paymentResult.transactionId);
      await this.orderRepository.save(order);

      // Publicar evento de éxito
      await this.eventBus.publish(new OrderPaidEvent(
        orderId.value,
        paymentResult.transactionId
      ));

      return paymentResult;

    } catch (error) {
      // COMPENSACIÓN
      console.log(`[Saga] Error: ${error.message}. Compensando...`);

      if (inventoryReservation) {
        console.log(`[Saga] Compensando: Liberando inventario`);
        await this.inventoryService.releaseReservation(inventoryReservation.id);
      }

      order.markPaymentFailed(error.message);
      await this.orderRepository.save(order);

      await this.eventBus.publish(new OrderPaymentFailedEvent(
        orderId.value,
        error.message
      ));

      throw error;
    }
  }
}
```

**Puntos clave de las Sagas:**

1. **Cada paso debe ser idempotente**: Si se reintenta, no debe causar duplicados
2. **Cada paso debe tener una compensación**: Una forma de "deshacer"
3. **El orden importa**: Primero lo más fácil de compensar
4. **Registra todo**: Para debugging y auditoría

---

# 9. Patrones Avanzados

## 9.1 Outbox Pattern

### El problema

Cuando guardas un agregado y publicas eventos, tienes dos operaciones:
1. Guardar en base de datos
2. Publicar en el message broker

¿Qué pasa si la BD se guarda pero el broker falla? Datos inconsistentes.

### La solución

El Outbox Pattern guarda los eventos en la MISMA transacción que los datos. Un proceso separado lee estos eventos y los publica.

```
┌─────────────────────────────────────────────────────┐
│                   TRANSACCIÓN                        │
│                                                      │
│   ┌─────────────────┐    ┌─────────────────┐        │
│   │  Tabla: Orders  │    │ Tabla: Outbox   │        │
│   │                 │    │                 │        │
│   │  UPDATE order   │    │  INSERT event   │        │
│   │  SET status=    │    │  (pendiente)    │        │
│   │  'CONFIRMED'    │    │                 │        │
│   └─────────────────┘    └─────────────────┘        │
└─────────────────────────────────────────────────────┘
                            │
                            │ Proceso separado
                            ▼
                    ┌───────────────┐
                    │ Outbox Worker │
                    │ 1. Lee evento │
                    │ 2. Publica    │
                    │ 3. Marca OK   │
                    └───────────────┘
```

### Implementación

```typescript
export class TransactionalOrderRepository implements OrderRepository {
  async save(order: Order): Promise<void> {
    const events = order.pullDomainEvents();

    await this.db.transaction(async (tx) => {
      // Guardar el pedido
      await tx.query('INSERT INTO orders...', [/* order data */]);

      // Guardar eventos en outbox (misma transacción)
      for (const event of events) {
        await tx.query(
          `INSERT INTO outbox_messages 
           (id, aggregate_type, aggregate_id, event_type, payload)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            event.eventId,
            event.aggregateType,
            event.aggregateId,
            event.eventType,
            JSON.stringify(event)
          ]
        );
      }
    });
  }
}

// Proceso que publica eventos pendientes
export class OutboxWorker {
  async processOutbox(): Promise<void> {
    const messages = await this.db.query(
      'SELECT * FROM outbox WHERE processed_at IS NULL LIMIT 100'
    );

    for (const msg of messages.rows) {
      try {
        await this.messageBroker.publish(msg.event_type, msg.payload);
        await this.db.query(
          'UPDATE outbox SET processed_at = NOW() WHERE id = $1',
          [msg.id]
        );
      } catch (error) {
        // Se reintentará en la próxima ejecución
        console.error(`Failed to process ${msg.id}:`, error);
      }
    }
  }

  start(): void {
    setInterval(() => this.processOutbox(), 1000);
  }
}
```

## 9.2 Specification Pattern

### El problema

Las reglas de negocio complejas terminan duplicadas en múltiples lugares.

### La solución

Encapsular reglas en objetos reutilizables que pueden combinarse con AND, OR, NOT.

```typescript
// Base
export abstract class CompositeSpecification<T> {
  abstract isSatisfiedBy(candidate: T): boolean;

  and(other: Specification<T>): Specification<T> {
    return new AndSpecification(this, other);
  }

  or(other: Specification<T>): Specification<T> {
    return new OrSpecification(this, other);
  }

  not(): Specification<T> {
    return new NotSpecification(this);
  }
}

// Especificaciones concretas
export class OrderIsConfirmedSpec extends CompositeSpecification<Order> {
  isSatisfiedBy(order: Order): boolean {
    return order.status === OrderStatus.CONFIRMED;
  }
}

export class OrderExceedsAmountSpec extends CompositeSpecification<Order> {
  constructor(private readonly minimumAmount: Money) { super(); }

  isSatisfiedBy(order: Order): boolean {
    return order.total().isGreaterThan(this.minimumAmount);
  }
}

// Uso combinado
const eligibleForFreeShipping = new OrderIsConfirmedSpec()
  .and(new OrderExceedsAmountSpec(Money.of(100, 'USD')));

if (eligibleForFreeShipping.isSatisfiedBy(order)) {
  order.applyFreeShipping();
}

// Filtrar colecciones
const priorityOrders = allOrders.filter(o => 
  eligibleForFreeShipping.isSatisfiedBy(o)
);
```

## 9.3 Anti-Corruption Layer (ACL)

### El problema

Integrar con sistemas externos "contamina" el dominio con sus modelos.

```typescript
// ❌ MAL: El dominio conoce estructuras de Stripe
class PaymentService {
  async processPayment(order: Order): Promise<void> {
    const stripeResponse = await stripe.charges.create({
      amount: order.total * 100,  // Stripe usa centavos
      currency: 'usd',
      source: order.customer.stripeToken,  // ¿stripeToken en Customer?
    });
    order.paymentId = stripeResponse.id;  // Estructura de Stripe
  }
}
```

### La solución

Una capa de traducción que protege el dominio.

```typescript
// El dominio define lo que necesita (puerto)
export interface PaymentGateway {
  processPayment(request: PaymentRequest): Promise<PaymentResult>;
}

export interface PaymentRequest {
  orderId: OrderId;
  amount: Money;
  customerId: CustomerId;
}

export interface PaymentResult {
  success: boolean;
  transactionId: TransactionId;
  errorMessage?: string;
}

// El ACL traduce entre Stripe y nuestro dominio
export class StripePaymentGateway implements PaymentGateway {
  async processPayment(request: PaymentRequest): Promise<PaymentResult> {
    try {
      // Traducir de nuestro modelo a Stripe
      const stripeRequest = {
        amount: this.toStripeCents(request.amount),
        currency: request.amount.getCurrency().toLowerCase(),
        customer: await this.getStripeCustomerId(request.customerId),
      };

      const stripeResponse = await this.stripe.paymentIntents.create(stripeRequest);

      // Traducir de Stripe a nuestro modelo
      return {
        success: stripeResponse.status === 'succeeded',
        transactionId: TransactionId.from(stripeResponse.id),
      };
    } catch (stripeError) {
      // Traducir errores
      return {
        success: false,
        transactionId: TransactionId.empty(),
        errorMessage: this.mapStripeError(stripeError)
      };
    }
  }

  private toStripeCents(money: Money): number {
    return Math.round(money.getAmount() * 100);
  }

  private mapStripeError(error: StripeError): string {
    switch (error.type) {
      case 'StripeCardError': return 'La tarjeta fue rechazada';
      case 'StripeInvalidRequestError': return 'Datos de pago inválidos';
      default: return 'Error procesando el pago';
    }
  }
}
```

**Beneficios del ACL:**
- El dominio no conoce Stripe
- Podríamos cambiar a PayPal sin tocar el dominio
- Los errores de Stripe se traducen a errores de dominio
- Los formatos se normalizan