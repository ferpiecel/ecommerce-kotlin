# Arquitectura Hexagonal y Domain-Driven Design

## Guía Completa: De Básico a Avanzado

*Con principios SOLID, orientación a eventos y ejemplos prácticos*

---

# Índice de Contenidos

1. Introducción y Fundamentos
2. Domain-Driven Design (DDD): El Corazón del Sistema
3. Arquitectura Hexagonal: La Estructura Técnica
4. Puertos: Los Contratos del Sistema
5. Adaptadores: Las Implementaciones Concretas
6. Principio de Responsabilidad Única (SRP)
7. Arquitectura Orientada a Eventos
8. Flujos de Aplicación Completos
9. Patrones Avanzados
10. Testing en Arquitectura Hexagonal
11. Mejores Prácticas y Anti-patrones

---

# 1. Introducción y Fundamentos

## 1.1 ¿Por qué necesitamos estas arquitecturas?

Imagina que construyes una casa. Si empiezas poniendo ladrillos sin un plano, probablemente termines con habitaciones que no conectan bien, tuberías que cruzan donde no deben, y una estructura difícil de modificar. Lo mismo ocurre con el software.

**Domain-Driven Design (DDD)** es como el proceso de entender qué tipo de casa necesitas: cuántas habitaciones, para qué se usará cada una, cómo vive la familia que la habitará. Se enfoca en entender profundamente el problema de negocio.

**Arquitectura Hexagonal** es el plano arquitectónico: dónde van las paredes maestras, cómo separar la zona de servicio de la zona habitable, dónde colocar las conexiones de agua y electricidad para que sean fáciles de mantener y modificar.

Juntos, DDD y Arquitectura Hexagonal te permiten construir software que:

- **Refleja el negocio real**: El código habla el mismo idioma que los expertos del dominio
- **Es fácil de cambiar**: Puedes modificar la base de datos, el framework web o las integraciones sin reescribir la lógica de negocio
- **Es testeable**: Puedes probar las reglas de negocio sin necesitar bases de datos ni servidores
- **Escala con el equipo**: Diferentes personas pueden trabajar en diferentes partes sin pisarse

## 1.2 La Relación entre DDD y Arquitectura Hexagonal

Piensa en DDD como el "qué" y Arquitectura Hexagonal como el "cómo":

| Aspecto | DDD | Arquitectura Hexagonal |
|---------|-----|------------------------|
| Pregunta que responde | ¿Qué problema resolvemos y cómo lo modelamos? | ¿Cómo organizamos el código técnicamente? |
| Enfoque | Modelado del dominio de negocio | Estructura y dependencias del código |
| Resultado | Entidades, Value Objects, Agregados, Eventos | Capas, Puertos, Adaptadores |
| Beneficio principal | Software que refleja el negocio | Software desacoplado y mantenible |

Ambos se complementan perfectamente: DDD te dice qué construir en el centro (el dominio), y Arquitectura Hexagonal te dice cómo proteger ese centro del mundo exterior.

---

# 2. Domain-Driven Design (DDD): El Corazón del Sistema

## 2.1 ¿Qué es Domain-Driven Design?

Domain-Driven Design es una filosofía de desarrollo que pone el **dominio del negocio** en el centro de todas las decisiones. Fue introducido por Eric Evans en 2003 y propone que el software más valioso es aquel que captura fielmente la complejidad del problema que resuelve.

La idea central es simple pero poderosa: **el código debe ser un modelo del negocio**. Si tu negocio habla de "pedidos", "clientes" y "envíos", tu código debe tener clases llamadas `Order`, `Customer` y `Shipment` que se comporten exactamente como esos conceptos funcionan en la realidad.

## 2.2 Lenguaje Ubicuo (Ubiquitous Language)

### ¿Qué es?

El Lenguaje Ubicuo es un vocabulario compartido entre desarrolladores y expertos del negocio. Es "ubicuo" porque se usa en todas partes: en las conversaciones, en la documentación, en el código, en las pruebas.

### ¿Por qué es importante?

Cuando un experto de negocio dice "el pedido se confirma" y el desarrollador entiende "se actualiza el campo status a 2", hay una desconexión. Esta desconexión causa bugs, malentendidos y software que no refleja la realidad.

Con Lenguaje Ubicuo, ambos usan los mismos términos con el mismo significado. El código literalmente dice `order.confirm()`, no `order.setStatus(2)`.

### Ejemplo práctico

**Sin Lenguaje Ubicuo:**
```
- Negocio dice: "El cliente reserva una habitación"
- Código dice: updateRoomStatus(roomId, 'BLOCKED', customerId)
```

**Con Lenguaje Ubicuo:**
```
- Negocio dice: "El cliente reserva una habitación"
- Código dice: room.reserveFor(customer)
```

El segundo ejemplo es código que cualquier persona del negocio podría leer y validar.

## 2.3 Bounded Contexts (Contextos Delimitados)

### ¿Qué es?

Un Bounded Context es una frontera conceptual donde un modelo de dominio particular es válido y consistente. Dentro de esa frontera, cada término tiene un significado preciso y único.

### ¿Por qué existe?

En una empresa real, la misma palabra puede significar cosas diferentes según el departamento:

- Para **Ventas**, un "Cliente" es alguien con datos de contacto y un historial de compras
- Para **Facturación**, un "Cliente" es una entidad con datos fiscales y condiciones de pago  
- Para **Envíos**, un "Cliente" es simplemente una dirección de entrega

Intentar crear un único modelo de "Cliente" que satisfaga a todos resulta en una clase gigante, confusa e imposible de mantener. Los Bounded Contexts permiten que cada área tenga su propio modelo, optimizado para sus necesidades.

### Ejemplo visual

```
┌─────────────────────────────────────────────────────────────────┐
│                         E-COMMERCE                               │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │  CONTEXTO:       │  │  CONTEXTO:       │  │  CONTEXTO:     │ │
│  │  VENTAS          │  │  INVENTARIO      │  │  ENVÍOS        │ │
│  │                  │  │                  │  │                │ │
│  │  - Cliente       │  │  - Producto      │  │  - Paquete     │ │
│  │  - Pedido        │  │  - Stock         │  │  - Ruta        │ │
│  │  - Carrito       │  │  - Almacén       │  │  - Destinatario│ │
│  │  - Producto*     │  │  - Movimiento    │  │  - Tracking    │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
│                                                                  │
│  * "Producto" en Ventas tiene precio y descripción comercial    │
│    "Producto" en Inventario tiene dimensiones y ubicación       │
└─────────────────────────────────────────────────────────────────┘
```

### Cómo se comunican los contextos

Los Bounded Contexts no viven aislados; necesitan compartir información. Esto se hace mediante:

- **Eventos de dominio**: Un contexto publica que algo ocurrió, otros reaccionan
- **APIs internas**: Un contexto expone servicios que otros consumen
- **Shared Kernel**: Código compartido mínimo cuando es estrictamente necesario

## 2.4 Entidades (Entities)

### ¿Qué es una Entidad?

Una Entidad es un objeto que tiene **identidad única** que persiste a lo largo del tiempo, independientemente de cómo cambien sus atributos.

### La clave: Identidad vs. Atributos

Piensa en una persona. Juan García puede cambiar de dirección, de trabajo, incluso de nombre, pero sigue siendo la misma persona. Lo que lo define no son sus atributos (que cambian), sino su identidad (que permanece).

Lo mismo ocurre con un Pedido en un sistema. El pedido #12345 puede cambiar de estado (pendiente → confirmado → enviado), pueden agregarse o quitarse productos, puede modificarse la dirección de envío. Pero sigue siendo el pedido #12345.

### Características de una Entidad

1. **Tiene un identificador único** (ID, UUID, código de negocio)
2. **Su identidad no cambia** aunque cambien todos sus demás atributos
3. **Dos entidades son iguales si tienen el mismo ID**, sin importar sus otros valores
4. **Tiene ciclo de vida**: nace, cambia de estado, eventualmente "muere" o se archiva

### Ejemplo conceptual

Un `Customer` es una Entidad porque:
- Tiene un ID único (ej: `customer-7829`)
- Puede cambiar de email, dirección, teléfono
- Sigue siendo el mismo cliente aunque cambie todo lo demás
- Dos clientes con el mismo nombre NO son el mismo cliente

### Ejemplo en código

```typescript
// domain/entities/Order.ts

export class Order {
  // El ID es inmutable - define la identidad
  private readonly id: OrderId;
  
  // Estos atributos pueden cambiar
  private items: OrderItem[];
  private status: OrderStatus;
  private shippingAddress: Address;
  
  // Fecha de creación - parte del ciclo de vida
  private readonly createdAt: Date;

  private constructor(
    id: OrderId,
    customerId: CustomerId,
    items: OrderItem[],
    status: OrderStatus
  ) {
    this.id = id;
    this.customerId = customerId;
    this.items = items;
    this.status = status;
    this.createdAt = new Date();
  }

  // Factory method - la forma correcta de crear entidades
  // Encapsula las reglas de creación
  static create(customerId: CustomerId): Order {
    return new Order(
      OrderId.generate(),
      customerId,
      [],
      OrderStatus.PENDING
    );
  }

  // Los métodos expresan comportamiento de negocio
  // No son simples setters
  addItem(product: Product, quantity: number): void {
    // Regla de negocio: solo pedidos pendientes pueden modificarse
    if (this.status !== OrderStatus.PENDING) {
      throw new OrderCannotBeModifiedError(this.id);
    }
    
    const item = OrderItem.create(product, quantity);
    this.items.push(item);
  }

  confirm(): void {
    // Regla de negocio: no se puede confirmar un pedido vacío
    if (this.items.length === 0) {
      throw new EmptyOrderCannotBeConfirmedError(this.id);
    }
    
    this.status = OrderStatus.CONFIRMED;
  }

  // Dos pedidos son iguales si tienen el mismo ID
  equals(other: Order): boolean {
    return this.id.equals(other.id);
  }
}
```

**Observa cómo:**
- El constructor es privado - fuerzas a usar el factory method
- Los métodos tienen nombres de negocio (`confirm`, no `setStatus`)
- Las reglas de negocio viven dentro de la entidad
- No hay setters públicos - el estado cambia mediante comportamiento

## 2.5 Value Objects (Objetos de Valor)

### ¿Qué es un Value Object?

Un Value Object es un objeto que se define completamente por sus atributos, no tiene identidad propia, y es inmutable.

### La clave: Igualdad por valor

Piensa en el dinero. Un billete de $100 es igual a cualquier otro billete de $100. No nos importa "cuál" billete específico es (su identidad), solo nos importa su valor. Si tienes dos billetes de $100, son intercambiables.

Lo mismo con una dirección: "Calle Principal 123, Ciudad X" es igual a otra instancia que tenga exactamente los mismos valores, no porque sean "la misma dirección" con un ID, sino porque sus valores son idénticos.

### Características de un Value Object

1. **Sin identidad**: No tiene ID, se define por sus atributos
2. **Inmutable**: Una vez creado, no cambia. Si necesitas un valor diferente, creas uno nuevo
3. **Igualdad por valor**: Dos Value Objects son iguales si todos sus atributos son iguales
4. **Auto-validante**: Se valida en el momento de creación

### ¿Por qué usar Value Objects?

**Sin Value Objects:**
```typescript
// ¿Es válido un precio negativo? ¿Quién lo valida?
order.price = -50;

// ¿Puedo sumar dólares con euros? El compilador no me detiene
const total = priceInUSD + priceInEUR;

// ¿Es este un email válido? Quién sabe...
customer.email = "esto no es un email";
```

**Con Value Objects:**
```typescript
// El Value Object rechaza valores inválidos al crearse
const price = Money.of(-50, 'USD'); // ¡Error! Cantidad negativa

// El Value Object previene operaciones sin sentido
const total = usdMoney.add(eurMoney); // ¡Error! Monedas diferentes

// El Value Object valida el formato
const email = Email.create("esto no es un email"); // ¡Error! Formato inválido
```

### Ejemplo en código: Money

```typescript
// domain/value-objects/Money.ts

export class Money {
  // Propiedades privadas e inmutables
  private constructor(
    private readonly amount: number,
    private readonly currency: Currency
  ) {
    // Validación en construcción - si llega aquí, es válido
    if (amount < 0) {
      throw new InvalidMoneyAmountError(amount);
    }
  }

  // Factory methods - formas controladas de crear instancias
  static of(amount: number, currency: Currency): Money {
    return new Money(amount, currency);
  }

  static zero(currency: Currency = Currency.USD): Money {
    return new Money(0, currency);
  }

  // Operaciones que retornan NUEVAS instancias (inmutabilidad)
  add(other: Money): Money {
    this.ensureSameCurrency(other);
    // No modificamos this.amount, creamos un nuevo Money
    return new Money(this.amount + other.amount, this.currency);
  }

  multiply(factor: number): Money {
    return new Money(this.amount * factor, this.currency);
  }

  // Igualdad por valor, no por referencia
  equals(other: Money): boolean {
    return this.amount === other.amount && 
           this.currency === other.currency;
  }

  // Validación interna
  private ensureSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new CurrencyMismatchError(this.currency, other.currency);
    }
  }
}
```

### Cuándo usar Entidad vs Value Object

| Pregunta | Si la respuesta es SÍ | Usa |
|----------|----------------------|-----|
| ¿Necesito rastrear este objeto a lo largo del tiempo? | Sí | Entidad |
| ¿Dos instancias con los mismos valores son intercambiables? | Sí | Value Object |
| ¿Este objeto tiene un ciclo de vida? | Sí | Entidad |
| ¿Este objeto simplemente representa un valor o medida? | Sí | Value Object |