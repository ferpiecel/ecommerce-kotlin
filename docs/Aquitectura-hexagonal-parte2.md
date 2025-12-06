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

      ↑
      │ El mundo exterior solo habla con Order
      │
  [Servicio de Aplicación]
```

### Reglas de los Agregados

1. **La raíz tiene identidad global**: Se puede referenciar desde cualquier parte
2. **Los objetos internos tienen identidad local**: Solo tienen sentido dentro del agregado
3. **Nada externo guarda referencias a objetos internos**: Solo a la raíz
4. **La raíz garantiza las invariantes**: Todas las reglas de consistencia
5. **Los agregados se persisten completos**: Se guardan y cargan como unidad

### Ejemplo en código

```typescript
// domain/aggregates/Order.ts

export class Order {  // Este es el Aggregate Root
  private readonly id: OrderId;
  private readonly customerId: CustomerId;
  private items: OrderItem[];  // Objetos internos del agregado
  private status: OrderStatus;

  // El mundo exterior pide agregar un item
  // Order decide cómo hacerlo y verifica las reglas
  addItem(product: Product, quantity: number): void {
    // Invariante: solo pedidos pendientes pueden modificarse
    this.ensureCanBeModified();
    
    // Invariante: cantidad debe ser positiva
    if (quantity <= 0) {
      throw new InvalidQuantityError(quantity);
    }

    const existingItem = this.findItemByProduct(product.id);
    
    if (existingItem) {
      existingItem.increaseQuantity(quantity);
    } else {
      this.items.push(OrderItem.create(product, quantity));
    }
  }

  confirm(): OrderConfirmedEvent {
    if (this.items.length === 0) {
      throw new EmptyOrderCannotBeConfirmedError(this.id);
    }
    
    if (this.status !== OrderStatus.PENDING) {
      throw new InvalidOrderStateTransitionError(this.status, OrderStatus.CONFIRMED);
    }
    
    this.status = OrderStatus.CONFIRMED;
    
    return new OrderConfirmedEvent(this.id, this.customerId, this.total());
  }

  total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.subtotal()),
      Money.zero()
    );
  }

  private ensureCanBeModified(): void {
    if (this.status !== OrderStatus.PENDING) {
      throw new OrderCannotBeModifiedError(this.id, this.status);
    }
  }
}
```

### Cómo determinar los límites de un Agregado

Preguntas guía:

1. **¿Qué debe ser consistente en una transacción?** Eso es un agregado
2. **¿Puede este objeto existir sin el otro?** Si no, probablemente están en el mismo agregado
3. **¿Quién es responsable de las reglas que involucran ambos objetos?** Ese es el Aggregate Root

## 2.7 Servicios de Dominio (Domain Services)

### ¿Qué es un Servicio de Dominio?

Un Servicio de Dominio encapsula lógica de negocio que **no pertenece naturalmente a ninguna entidad** específica. Es una operación del dominio que involucra múltiples objetos o conceptos externos al objeto mismo.

### ¿Cuándo usar un Servicio de Dominio?

1. La operación involucra **múltiples agregados**
2. La lógica requiere **información externa** que la entidad no debería conocer
3. Poner la lógica en una entidad la haría **conocer demasiado** sobre otras

### Ejemplo: Lógica de pricing

Imagina que el precio depende de: el cliente (VIP), la cantidad (descuentos por volumen), promociones activas, impuestos por país.

¿Pertenece a `Product`? No, no debería conocer sobre clientes.
¿Pertenece a `Customer`? No, no debería conocer sobre productos.
¿Pertenece a `Order`? Parcialmente, pero no sobre promociones activas.

**Solución: un Domain Service**

```typescript
// domain/services/PricingService.ts

export class PricingService {
  constructor(
    private readonly promotionRules: PromotionRules,
    private readonly taxCalculator: TaxCalculator
  ) {}

  calculatePrice(
    product: Product,
    quantity: number,
    customer: Customer,
    shippingCountry: Country
  ): PriceCalculation {
    
    let price = product.basePrice.multiply(quantity);
    
    if (customer.isVIP()) {
      price = price.applyDiscount(Percentage.of(10));
    }
    
    const volumeDiscount = this.calculateVolumeDiscount(quantity);
    price = price.applyDiscount(volumeDiscount);
    
    const promotions = this.promotionRules.findApplicable(product, customer);
    for (const promo of promotions) {
      price = promo.applyTo(price);
    }
    
    const taxes = this.taxCalculator.calculate(price, shippingCountry);
    
    return new PriceCalculation(price, taxes, price.add(taxes));
  }
}
```

### Domain Service vs Application Service

| Aspecto | Domain Service | Application Service |
|---------|---------------|---------------------|
| Contiene | Lógica de negocio | Orquestación |
| Conoce | Entidades, Value Objects | Puertos, repositorios |
| Ejemplo | Calcular precio con reglas complejas | Crear pedido y notificar |
| Dependencias | Solo dominio | Dominio + infraestructura (vía puertos) |

## 2.8 Eventos de Dominio (Domain Events)

### ¿Qué es un Evento de Dominio?

Un Evento de Dominio representa **algo significativo que ocurrió** en el dominio. Es un hecho histórico, inmutable, que otros componentes pueden necesitar conocer.

### Características clave

1. **Describe algo que YA ocurrió** (pasado): `OrderConfirmed`, no `ConfirmOrder`
2. **Es inmutable**: Una vez creado, no cambia
3. **Contiene toda la información necesaria** para que otros reaccionen
4. **Es parte del lenguaje ubicuo**: Los expertos de negocio entienden estos eventos

### ¿Por qué usar Eventos de Dominio?

**Sin eventos (acoplamiento directo):**
```typescript
class OrderService {
  confirmOrder(orderId: string): void {
    const order = this.orderRepo.findById(orderId);
    order.confirm();
    this.orderRepo.save(order);
    
    // El servicio "conoce" todo lo que debe pasar después
    this.emailService.sendConfirmation(order);
    this.inventoryService.reserveStock(order);
    this.analyticsService.recordSale(order);
    // ¿Y si mañana necesito agregar otra cosa?
  }
}
```

**Con eventos (desacoplamiento):**
```typescript
class OrderService {
  confirmOrder(orderId: string): void {
    const order = this.orderRepo.findById(orderId);
    order.confirm();
    this.orderRepo.save(order);
    
    // Solo publicamos que algo ocurrió
    this.eventBus.publish(new OrderConfirmedEvent(order));
  }
}

// Cada servicio interesado se suscribe independientemente
class SendConfirmationEmailHandler {
  handle(event: OrderConfirmedEvent): void {
    this.emailService.sendConfirmation(event.orderId);
  }
}
```

### Ejemplo de Evento de Dominio

```typescript
// domain/events/DomainEvent.ts

export abstract class DomainEvent {
  public readonly eventId: string;
  public readonly occurredOn: Date;
  public readonly aggregateId: string;

  constructor(aggregateId: string) {
    this.eventId = generateUUID();
    this.occurredOn = new Date();
    this.aggregateId = aggregateId;
  }

  abstract get eventType(): string;
  abstract get aggregateType(): string;
}


// domain/events/OrderConfirmedEvent.ts

export class OrderConfirmedEvent extends DomainEvent {
  constructor(
    orderId: string,
    public readonly customerId: string,
    public readonly totalAmount: Money,
    public readonly items: OrderItemDTO[]
  ) {
    super(orderId);
  }

  get eventType(): string {
    return 'order.confirmed';
  }

  get aggregateType(): string {
    return 'Order';
  }
}
```

## 2.9 Repositorios (Repositories)

### ¿Qué es un Repositorio?

Un Repositorio es una abstracción que simula una **colección de objetos de dominio**. Desde la perspectiva del dominio, es como si todos los agregados estuvieran en memoria.

### La metáfora de la colección

Piensa en un Repositorio como una lista mágica:
- `repository.save(order)` → Agregar/actualizar en la colección
- `repository.findById(id)` → Buscar en la colección
- `repository.delete(order)` → Quitar de la colección

El dominio trabaja con esta abstracción simple. Cómo se implementa (SQL, HTTP, archivos) es problema de la infraestructura.

### Repositorio como Interface (Puerto)

```typescript
// domain/repositories/OrderRepository.ts
// Esta es la INTERFACE - vive en el dominio

export interface OrderRepository {
  save(order: Order): Promise<void>;
  delete(id: OrderId): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  findByStatus(status: OrderStatus): Promise<Order[]>;
  nextId(): OrderId;
}
```

---

# 3. Arquitectura Hexagonal: La Estructura Técnica

## 3.1 ¿Qué es la Arquitectura Hexagonal?

La Arquitectura Hexagonal, también llamada **Puertos y Adaptadores**, fue propuesta por Alistair Cockburn en 2005. Su objetivo es crear aplicaciones donde el núcleo de negocio esté completamente aislado del mundo exterior.

### La metáfora del hexágono

Imagina tu aplicación como un hexágono. El hexágono tiene múltiples lados (puertos), y cada lado puede conectarse con el exterior mediante adaptadores. No hay un lado "especial" - la interfaz web, la API REST, una cola de mensajes... todos son simplemente adaptadores conectados a puertos.

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
         │  │                                 │  │
         │  │      DOMINIO Y APLICACIÓN       │  │
         │  │    (Lógica de negocio pura)     │  │
         │  │                                 │  │
         │  └─────────────────────────────────┘  │
         │                                       │
         │  ┌─────────────────────────────────┐  │
         │  │       PUERTO SECUNDARIO         │  │
         │  │      (Interface de salida)      │  │
         └──┴─────────────────────────────────┴──┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │PostgreSQL│  │ RabbitMQ │  │ SendGrid │
        │Adaptador │  │ Adaptador│  │ Adaptador│
        └──────────┘  └──────────┘  └──────────┘
```

## 3.2 Las Tres Zonas

### Zona Interior: Dominio

El corazón del hexágono. Contiene:
- Entidades y Value Objects
- Eventos de Dominio
- Servicios de Dominio
- Interfaces de Repositorio (solo las interfaces)

**Regla de oro**: El dominio NO conoce nada del exterior. No importa frameworks, bases de datos, ni bibliotecas externas.

### Zona Media: Aplicación

Orquesta los casos de uso. Contiene:
- Servicios de Aplicación
- Handlers de Comandos y Queries
- Handlers de Eventos
- DTOs para entrada/salida

**Responsabilidad**: Coordinar. No contiene lógica de negocio, solo dice "primero haz esto, luego aquello".

### Zona Exterior: Infraestructura

Conecta con el mundo real. Contiene:
- Adaptadores primarios (REST, GraphQL, CLI)
- Adaptadores secundarios (PostgreSQL, Redis, SendGrid)
- Configuración y Dependency Injection
- Mappers entre formatos

## 3.3 La Regla de Dependencia

**Las dependencias siempre apuntan hacia adentro.**

```
Infraestructura → Aplicación → Dominio
     (afuera)       (medio)     (centro)
```

- Infraestructura conoce Aplicación y Dominio
- Aplicación conoce Dominio
- Dominio NO conoce nada más

Esto significa que puedes cambiar cualquier cosa en infraestructura sin tocar el dominio.