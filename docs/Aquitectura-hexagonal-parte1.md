# Arquitectura Hexagonal y Domain-Driven Design

## Guía Completa: De Básico a Avanzado

*Con principios SOLID, orientación a eventos y ejemplos prácticos en Java 21*

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
- Código dice: updateRoomStatus(roomId, "BLOCKED", customerId)
```

**Con Lenguaje Ubicuo:**
```
- Negocio dice: "El cliente reserva una habitación"
- Código dice: room.reserveFor(customer)
```

## 2.3 Bounded Contexts (Contextos Delimitados)

### ¿Qué es?

Un Bounded Context es una frontera conceptual donde un modelo de dominio particular es válido y consistente. Dentro de esa frontera, cada término tiene un significado preciso y único.

### ¿Por qué existe?

En una empresa real, la misma palabra puede significar cosas diferentes según el departamento:

- Para **Ventas**, un "Cliente" es alguien con datos de contacto y un historial de compras
- Para **Facturación**, un "Cliente" es una entidad con datos fiscales y condiciones de pago  
- Para **Envíos**, un "Cliente" es simplemente una dirección de entrega

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
└─────────────────────────────────────────────────────────────────┘
```

## 2.4 Entidades (Entities)

### ¿Qué es una Entidad?

Una Entidad es un objeto que tiene **identidad única** que persiste a lo largo del tiempo, independientemente de cómo cambien sus atributos.

### Características de una Entidad

1. **Tiene un identificador único** (ID, UUID, código de negocio)
2. **Su identidad no cambia** aunque cambien todos sus demás atributos
3. **Dos entidades son iguales si tienen el mismo ID**
4. **Tiene ciclo de vida**: nace, cambia de estado, eventualmente "muere"

### Ejemplo en código (Java 21)

```java
// domain/entity/Order.java

public class Order {
    
    // El ID es inmutable - define la identidad
    private final OrderId id;
    private final CustomerId customerId;
    private final Instant createdAt;
    
    // Estos atributos pueden cambiar
    private List<OrderItem> items;
    private OrderStatus status;
    private Address shippingAddress;
    
    // Lista de eventos de dominio pendientes
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    // Constructor privado - fuerza a usar factory method
    private Order(OrderId id, CustomerId customerId) {
        this.id = id;
        this.customerId = customerId;
        this.items = new ArrayList<>();
        this.status = OrderStatus.PENDING;
        this.createdAt = Instant.now();
    }

    // Factory method - la forma correcta de crear entidades
    public static Order create(CustomerId customerId) {
        var order = new Order(OrderId.generate(), customerId);
        
        order.recordEvent(new OrderCreatedEvent(
            order.id.value(),
            customerId.value(),
            order.createdAt
        ));
        
        return order;
    }

    // Los métodos expresan comportamiento de negocio
    public void addItem(Product product, int quantity) {
        // Regla de negocio: solo pedidos pendientes pueden modificarse
        if (status != OrderStatus.PENDING) {
            throw new OrderCannotBeModifiedException(id);
        }
        
        if (quantity <= 0) {
            throw new InvalidQuantityException(quantity);
        }
        
        // Buscar si ya existe el producto
        var existingItem = findItemByProduct(product.getId());
        
        if (existingItem.isPresent()) {
            existingItem.get().increaseQuantity(quantity);
        } else {
            items.add(OrderItem.create(product, quantity));
        }
    }

    public void confirm() {
        // Regla de negocio: no se puede confirmar un pedido vacío
        if (items.isEmpty()) {
            throw new EmptyOrderCannotBeConfirmedException(id);
        }
        
        if (status != OrderStatus.PENDING) {
            throw new InvalidOrderStateTransitionException(status, OrderStatus.CONFIRMED);
        }
        
        this.status = OrderStatus.CONFIRMED;
        
        recordEvent(new OrderConfirmedEvent(
            id.value(),
            customerId.value(),
            calculateTotal(),
            Instant.now()
        ));
    }

    public Money calculateTotal() {
        return items.stream()
            .map(OrderItem::subtotal)
            .reduce(Money.zero(Currency.USD), Money::add);
    }

    private Optional<OrderItem> findItemByProduct(ProductId productId) {
        return items.stream()
            .filter(item -> item.getProductId().equals(productId))
            .findFirst();
    }

    // Dos pedidos son iguales si tienen el mismo ID
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

    // Gestión de eventos de dominio
    protected void recordEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    public List<DomainEvent> pullDomainEvents() {
        var events = List.copyOf(domainEvents);
        domainEvents.clear();
        return events;
    }

    // Getters (sin setters públicos)
    public OrderId getId() { return id; }
    public CustomerId getCustomerId() { return customerId; }
    public OrderStatus getStatus() { return status; }
    public List<OrderItem> getItems() { return List.copyOf(items); }
    public Instant getCreatedAt() { return createdAt; }
}
```

**Observa cómo:**
- El constructor es privado - fuerzas a usar el factory method
- Los métodos tienen nombres de negocio (`confirm`, no `setStatus`)
- Las reglas de negocio viven dentro de la entidad
- No hay setters públicos - el estado cambia mediante comportamiento
- Usamos `List.copyOf()` para retornar copias inmutables

## 2.5 Value Objects (Objetos de Valor)

### ¿Qué es un Value Object?

Un Value Object es un objeto que se define completamente por sus atributos, no tiene identidad propia, y es inmutable.

### Características de un Value Object

1. **Sin identidad**: No tiene ID, se define por sus atributos
2. **Inmutable**: Una vez creado, no cambia
3. **Igualdad por valor**: Dos Value Objects son iguales si todos sus atributos son iguales
4. **Auto-validante**: Se valida en el momento de creación

### Ejemplo en código: Money (usando Record de Java 21)

```java
// domain/valueobject/Money.java

public record Money(BigDecimal amount, Currency currency) {
    
    // Constructor compacto con validación
    public Money {
        Objects.requireNonNull(amount, "Amount cannot be null");
        Objects.requireNonNull(currency, "Currency cannot be null");
        
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new InvalidMoneyAmountException(amount);
        }
    }

    // Factory methods
    public static Money of(BigDecimal amount, Currency currency) {
        return new Money(amount, currency);
    }

    public static Money of(double amount, Currency currency) {
        return new Money(BigDecimal.valueOf(amount), currency);
    }

    public static Money zero(Currency currency) {
        return new Money(BigDecimal.ZERO, currency);
    }

    // Operaciones que retornan NUEVAS instancias (inmutabilidad)
    public Money add(Money other) {
        ensureSameCurrency(other);
        return new Money(this.amount.add(other.amount), this.currency);
    }

    public Money subtract(Money other) {
        ensureSameCurrency(other);
        var result = this.amount.subtract(other.amount);
        if (result.compareTo(BigDecimal.ZERO) < 0) {
            throw new InsufficientFundsException(this, other);
        }
        return new Money(result, this.currency);
    }

    public Money multiply(int factor) {
        return new Money(this.amount.multiply(BigDecimal.valueOf(factor)), this.currency);
    }

    public boolean isGreaterThan(Money other) {
        ensureSameCurrency(other);
        return this.amount.compareTo(other.amount) > 0;
    }

    private void ensureSameCurrency(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new CurrencyMismatchException(this.currency, other.currency);
        }
    }
}
```

### Otros Value Objects comunes

```java
// domain/valueobject/Email.java

public record Email(String value) {
    
    private static final Pattern EMAIL_PATTERN = 
        Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");

    public Email {
        Objects.requireNonNull(value, "Email cannot be null");
        var normalized = value.toLowerCase().trim();
        if (!EMAIL_PATTERN.matcher(normalized).matches()) {
            throw new InvalidEmailException(value);
        }
    }

    public static Email of(String value) {
        return new Email(value.toLowerCase().trim());
    }
}


// domain/valueobject/OrderId.java

public record OrderId(String value) {
    
    public OrderId {
        Objects.requireNonNull(value, "OrderId cannot be null");
        if (value.isBlank()) {
            throw new InvalidOrderIdException("OrderId cannot be blank");
        }
    }

    public static OrderId generate() {
        return new OrderId(UUID.randomUUID().toString());
    }

    public static OrderId of(String value) {
        return new OrderId(value);
    }
}


// domain/valueobject/Address.java

public record Address(
    String street,
    String city,
    String state,
    String zipCode,
    String country
) {
    public Address {
        Objects.requireNonNull(street, "Street cannot be null");
        Objects.requireNonNull(city, "City cannot be null");
        Objects.requireNonNull(country, "Country cannot be null");
        
        if (street.isBlank() || city.isBlank() || country.isBlank()) {
            throw new InvalidAddressException("Street, city and country are required");
        }
    }

    public String fullAddress() {
        return "%s, %s, %s %s, %s".formatted(street, city, state, zipCode, country);
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