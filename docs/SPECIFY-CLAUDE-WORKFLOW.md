# Workflow con Specify + Claude Code - Guía Completa

## Índice
1. [¿Qué es Specify?](#qué-es-specify)
2. [¿Qué es Claude Code?](#qué-es-claude-code)
3. [¿Cómo trabajan juntos?](#cómo-trabajan-juntos)
4. [Workflow Recomendado](#workflow-recomendado)
5. [Épicas vs Historias vs Tareas](#épicas-vs-historias-vs-tareas)
6. [Ejemplo Práctico: Implementar Identity Context](#ejemplo-práctico)
7. [PRs Atómicos y de Valor](#prs-atómicos-y-de-valor)
8. [Mejores Prácticas](#mejores-prácticas)

---

## ¿Qué es Specify?

**Specify** es una herramienta para gestionar especificaciones de software usando archivos markdown.

### Estructura de Specify

```
.specify/
├── epics/              # Épicas (grandes objetivos de negocio)
│   ├── E001-user-authentication.md
│   └── E002-product-catalog.md
├── stories/            # Historias de usuario
│   ├── S001-login-flow.md
│   ├── S002-product-listing.md
│   └── S003-product-creation.md
└── tasks/              # Tareas técnicas
    ├── T001-implement-user-entity.md
    ├── T002-create-login-endpoint.md
    └── T003-add-product-repository.md
```

### Ventajas de Specify

✅ **Versionado con Git** - Las especificaciones están en el repo
✅ **Trazabilidad** - De épica → historia → tarea → código
✅ **Colaboración** - El equipo ve las especificaciones en el mismo lugar
✅ **Formato markdown** - Fácil de leer y editar
✅ **Integración con Claude Code** - Claude puede leer y actualizar las specs

---

## ¿Qué es Claude Code?

**Claude Code** es un IDE AI que puede:
- Leer y entender tu codebase completo
- Ejecutar comandos (build, test, git)
- Hacer cambios en múltiples archivos
- Crear commits y PRs
- Leer especificaciones de Specify

### Capacidades Clave

```bash
# Claude puede hacer esto automáticamente:
1. Leer .specify/stories/S003-product-creation.md
2. Implementar Product domain model
3. Implementar ProductRepository
4. Implementar CreateProductUseCase
5. Implementar ProductController
6. Escribir tests
7. git add .
8. git commit -m "feat: implement product creation (S003)"
9. git push
10. Crear PR con descripción automática
```

---

## ¿Cómo trabajan juntos?

### Flujo de Trabajo Típico

```
1. Tú defines la ÉPICA en Specify
   .specify/epics/E001-catalog-context.md

2. Descompones en HISTORIAS
   .specify/stories/S001-product-crud.md
   .specify/stories/S002-category-management.md

3. Cada historia se descompone en TAREAS
   .specify/tasks/T001-product-domain.md
   .specify/tasks/T002-product-repository.md
   .specify/tasks/T003-product-use-cases.md
   .specify/tasks/T004-product-api.md

4. Le dices a Claude: "Implementa T001"

5. Claude:
   - Lee T001-product-domain.md
   - Lee el contexto del proyecto
   - Implementa el código
   - Escribe tests
   - Hace commit
   - Actualiza T001 a "completed"

6. Revisas el PR (pequeño, atómico, de valor)

7. Merges y repites con T002, T003, etc.
```

---

## Workflow Recomendado

### Fase 1: Planificación (Tú + Specify)

#### 1.1 Crear Épica

```bash
specify epic create "Catalog Context Implementation"
```

Esto crea `.specify/epics/E001-catalog-context.md`:

```markdown
# Epic: Catalog Context Implementation

## Objetivo de Negocio
Implementar el bounded context de Catálogo con arquitectura hexagonal y DDD,
permitiendo la gestión completa de productos y categorías.

## Valor para el Usuario
- Vendedores pueden crear y administrar productos
- Compradores pueden ver y buscar productos
- Sistema mantiene inventario actualizado

## Alcance
- Gestión de productos (CRUD)
- Gestión de categorías (CRUD)
- Manejo de inventario
- Búsqueda de productos

## Fuera de Alcance
- Precios dinámicos
- Recomendaciones
- Reviews de productos

## Criterios de Aceptación de la Épica
- [ ] CRUD completo de productos funcional
- [ ] CRUD completo de categorías funcional
- [ ] Reserva y liberación de inventario
- [ ] Búsqueda por nombre y categoría
- [ ] Tests con 80%+ cobertura
- [ ] Documentación API en Swagger
- [ ] Migrations de BD aplicadas

## Historias de Usuario
- S001: Product CRUD
- S002: Category Management
- S003: Inventory Management
- S004: Product Search

## Estimación
- Esfuerzo: 40 story points
- Duración: 2 sprints
```

#### 1.2 Crear Historias de Usuario

```bash
specify story create "Product CRUD" --epic E001
```

`.specify/stories/S001-product-crud.md`:

```markdown
# Story: Product CRUD

## Epic
E001-catalog-context

## Como
Vendedor

## Quiero
Poder crear, ver, actualizar y eliminar productos

## Para
Mantener mi catálogo actualizado y disponible para los compradores

## Criterios de Aceptación

### AC1: Crear Producto
- [ ] Puedo crear un producto con SKU, nombre, descripción, precio
- [ ] El sistema valida que el SKU sea único
- [ ] El sistema valida que el precio sea positivo
- [ ] Se genera un ID único automáticamente
- [ ] Se registra evento ProductCreated

### AC2: Listar Productos
- [ ] Puedo ver todos mis productos con paginación
- [ ] Puedo filtrar por categoría
- [ ] Puedo buscar por nombre o SKU
- [ ] La lista muestra: nombre, SKU, precio, stock

### AC3: Ver Detalle de Producto
- [ ] Puedo ver todos los detalles de un producto
- [ ] Si el producto no existe, recibo error 404

### AC4: Actualizar Producto
- [ ] Puedo cambiar nombre, descripción, precio
- [ ] NO puedo cambiar el SKU (immutable)
- [ ] Se validan los mismos constraints que en creación
- [ ] Se registra evento ProductUpdated

### AC5: Eliminar Producto
- [ ] Puedo eliminar un producto (soft delete)
- [ ] El producto no aparece en listados
- [ ] Se registra evento ProductDeleted

## Definición de Hecho (DoD)
- [ ] Código implementado siguiendo Hexagonal + DDD
- [ ] Tests unitarios del dominio
- [ ] Tests de integración de API
- [ ] Documentación en Swagger
- [ ] Migration de BD
- [ ] Code review aprobado
- [ ] PR mergeado

## Tareas Técnicas
- T001: Implement Product Domain Model
- T002: Implement Product Repository
- T003: Implement Product Use Cases
- T004: Implement Product REST API
- T005: Write Domain Tests
- T006: Write Integration Tests

## Estimación
- Story Points: 8
- Horas estimadas: 12-16h
```

#### 1.3 Crear Tareas Técnicas

```bash
specify task create "Implement Product Domain Model" --story S001
```

`.specify/tasks/T001-product-domain-model.md`:

```markdown
# Task: Implement Product Domain Model

## Story
S001-product-crud

## Descripción
Implementar el modelo de dominio Product como Aggregate Root siguiendo
principios de DDD y arquitectura hexagonal.

## Alcance Técnico

### 1. Value Objects
- [x] ProductId (strongly-typed ID)
- [x] CategoryId (strongly-typed ID)
- [ ] Sku (con validación de formato)
- [ ] ProductName (con validación de longitud)
- [ ] Description (opcional)

### 2. Product Aggregate Root
- [ ] Constructor privado
- [ ] Factory method `Product.create()`
- [ ] Métodos de negocio:
  - [ ] `changeName(newName: ProductName)`
  - [ ] `changePrice(newPrice: Money)`
  - [ ] `changeDescription(desc: Description?)`
  - [ ] `activate()`
  - [ ] `deactivate()`
  - [ ] `reserveStock(quantity: Int)`
  - [ ] `releaseStock(quantity: Int)`
  - [ ] `addStock(quantity: Int)`

### 3. Domain Events
- [ ] ProductCreated
- [ ] ProductNameChanged
- [ ] ProductPriceChanged
- [ ] ProductActivated
- [ ] ProductDeactivated
- [ ] StockReserved
- [ ] StockReleased
- [ ] StockAdded

### 4. Invariantes a Proteger
- [ ] SKU es único (validado en use case)
- [ ] Precio siempre positivo
- [ ] Stock nunca negativo
- [ ] Nombre no puede ser vacío
- [ ] Solo productos activos pueden reservar stock

## Archivos a Crear/Modificar

```
catalog/domain/
├── model/
│   ├── Product.kt          # CREAR
│   ├── ProductId.kt        # CREAR
│   ├── Sku.kt              # CREAR
│   ├── ProductName.kt      # CREAR
│   └── Description.kt      # CREAR
└── event/
    ├── ProductCreated.kt   # CREAR
    ├── ProductNameChanged.kt    # CREAR
    ├── ProductPriceChanged.kt   # CREAR
    ├── StockReserved.kt    # CREAR
    └── StockReleased.kt    # CREAR
```

## Ejemplo de Código Esperado

```kotlin
// ProductId.kt
@JvmInline
value class ProductId(val value: UUID) {
    companion object {
        fun generate(): ProductId = ProductId(UUID.randomUUID())
        fun from(value: String): ProductId = ProductId(UUID.fromString(value))
    }
}

// Sku.kt
@JvmInline
value class Sku(val value: String) {
    init {
        require(value.matches(Regex("^[A-Z0-9]{6,20}$"))) {
            "SKU must be 6-20 alphanumeric characters"
        }
    }
}

// Product.kt
class Product private constructor(
    override val id: ProductId,
    private var sku: Sku,
    private var name: ProductName,
    private var description: Description?,
    private var price: Money,
    private var stockQuantity: Int,
    private val categoryId: CategoryId,
    private var slug: String,
    private var isActive: Boolean
) : AggregateRoot<ProductId>() {

    // Getters
    fun getSku(): Sku = sku
    fun getName(): ProductName = name
    // ... etc

    companion object {
        fun create(
            sku: Sku,
            name: ProductName,
            description: Description?,
            price: Money,
            initialStock: Int,
            categoryId: CategoryId,
            slug: String
        ): Product {
            require(initialStock >= 0) { "Initial stock cannot be negative" }
            require(price.isPositive()) { "Price must be positive" }

            val product = Product(
                id = ProductId.generate(),
                sku = sku,
                name = name,
                description = description,
                price = price,
                stockQuantity = initialStock,
                categoryId = categoryId,
                slug = slug,
                isActive = true
            )

            product.registerEvent(
                ProductCreated(
                    productId = product.id,
                    sku = sku,
                    name = name,
                    price = price
                )
            )

            return product
        }
    }

    fun changePrice(newPrice: Money) {
        require(newPrice.isPositive()) { "Price must be positive" }
        val oldPrice = price
        price = newPrice
        registerEvent(ProductPriceChanged(id, oldPrice, newPrice))
    }

    fun reserveStock(quantity: Int) {
        require(isActive) { "Cannot reserve stock for inactive product" }
        require(quantity > 0) { "Quantity must be positive" }
        require(stockQuantity >= quantity) {
            "Insufficient stock. Available: $stockQuantity, requested: $quantity"
        }

        stockQuantity -= quantity
        registerEvent(StockReserved(id, quantity, stockQuantity))
    }

    // ... otros métodos
}
```

## Criterios de Aceptación Técnicos
- [ ] Código sigue convenciones de Kotlin
- [ ] No hay dependencias de frameworks en el dominio
- [ ] Todas las propiedades son privadas
- [ ] Métodos de negocio expresivos (ubiquitous language)
- [ ] Eventos registrados en cada operación importante
- [ ] Invariantes protegidos

## Tests Requeridos
- [ ] Test: create product with valid data
- [ ] Test: create product with negative price throws exception
- [ ] Test: reserve stock reduces quantity
- [ ] Test: reserve more stock than available throws exception
- [ ] Test: reserve stock on inactive product throws exception
- [ ] Test: change price registers event
- [ ] Test: newly created product is active

## Estimación
- Horas: 3-4h
- Complejidad: Media

## Dependencias
- Ninguna (se puede implementar primero)

## Bloqueadores
- Ninguno

## Notas
- Usar los Value Objects del Shared Kernel (Money, Email, Address)
- Seguir el patrón establecido en docs/HEXAGONAL-ARCHITECTURE.md
- Referirse a docs/DOMAIN-DRIVEN-DESIGN.md para guía de Aggregates
```

### Fase 2: Implementación (Claude Code)

#### 2.1 Pedir a Claude que implemente una tarea

```
Prompt para Claude Code:

"Lee la tarea T001-product-domain-model.md y implementa todo lo especificado.
Sigue estrictamente los principios de Hexagonal Architecture y DDD descritos
en docs/HEXAGONAL-ARCHITECTURE.md.

Cuando termines:
1. Ejecuta los tests
2. Haz commit con el mensaje: 'feat(catalog): implement product domain model (T001)'
3. Actualiza T001 marcándola como completada
4. Dame un resumen de lo implementado
"
```

#### 2.2 Claude implementa

Claude hará:
1. Leer T001 para entender el alcance
2. Leer docs/HEXAGONAL-ARCHITECTURE.md y DOMAIN-DRIVEN-DESIGN.md
3. Crear todos los archivos necesarios
4. Implementar el código
5. Escribir los tests
6. Ejecutar `./gradlew test`
7. Si pasan, hacer commit
8. Actualizar `.specify/tasks/T001-product-domain-model.md` con estado completado

#### 2.3 Tú revisas

```bash
git log -1 --stat  # Ver qué cambió
git show           # Ver el diff completo
./gradlew test     # Verificar tests
```

Si todo está bien, continúas con T002.

### Fase 3: Pull Requests Atómicos

#### Estrategia de PRs

**❌ MAL - PR Monolítico:**
```
PR #1: "Implement Catalog Context" (200 archivos)
- Domain
- Application
- Infrastructure
- Tests
- Migrations
- Documentación
```

**✅ BIEN - PRs Atómicos:**

```
PR #1: "feat(catalog): product domain model (T001)"
├── catalog/domain/model/Product.kt
├── catalog/domain/model/ProductId.kt
├── catalog/domain/model/Sku.kt
├── catalog/domain/event/ProductCreated.kt
└── catalog/domain/model/ProductTest.kt
Total: 5 archivos, ~300 LOC

PR #2: "feat(catalog): product repository port and adapter (T002)"
├── catalog/domain/repository/ProductRepository.kt
├── catalog/infrastructure/persistence/R2dbcProductRepository.kt
├── catalog/infrastructure/persistence/mapper/ProductMapper.kt
└── catalog/infrastructure/persistence/R2dbcProductRepositoryTest.kt
Total: 4 archivos, ~200 LOC

PR #3: "feat(catalog): product use cases (T003)"
├── catalog/application/usecase/CreateProductUseCase.kt
├── catalog/application/usecase/GetProductByIdUseCase.kt
├── catalog/application/command/CreateProductCommand.kt
├── catalog/application/dto/ProductDTO.kt
└── catalog/application/usecase/CreateProductUseCaseTest.kt
Total: 5 archivos, ~250 LOC

PR #4: "feat(catalog): product REST API (T004)"
├── catalog/infrastructure/web/ProductController.kt
├── catalog/infrastructure/web/ProductRequest.kt
├── catalog/infrastructure/web/ProductResponse.kt
└── catalog/infrastructure/web/ProductControllerTest.kt
Total: 4 archivos, ~200 LOC
```

#### Ventajas de PRs Atómicos

✅ **Revisión más fácil** - 5 archivos vs 200 archivos
✅ **Menos conflictos** - Cambios pequeños y frecuentes
✅ **Revert más seguro** - Si T003 tiene un bug, revertir solo ese PR
✅ **Mejor trazabilidad** - Commit → Task → Story → Epic
✅ **CI/CD más rápido** - Tests más rápidos en cada PR
✅ **Deploy incremental** - Puedes deployar después de cada PR

---

## Épicas vs Historias vs Tareas

### Épica (Epic)

**¿Qué es?**
Gran objetivo de negocio que toma múltiples sprints.

**Tamaño:** 20-100 story points, 1-3 meses

**Ejemplos:**
- "Sistema de Autenticación Completo"
- "Implementar Catalog Context"
- "Sistema de Pagos"

**Estructura:**
```markdown
# Epic: E001-catalog-context

## Objetivo de Negocio
[Qué valor aporta al usuario final]

## Alcance
[Qué incluye]

## Fuera de Alcance
[Qué NO incluye]

## Historias
- S001
- S002
- S003

## Estimación
40 story points, 2 sprints
```

### Historia de Usuario (User Story)

**¿Qué es?**
Funcionalidad desde la perspectiva del usuario.

**Tamaño:** 3-13 story points, 2-5 días

**Formato:**
```
Como [rol]
Quiero [funcionalidad]
Para [beneficio]
```

**Ejemplos:**
- "Como vendedor, quiero crear productos para venderlos en mi tienda"
- "Como comprador, quiero buscar productos para encontrar lo que necesito"

**Estructura:**
```markdown
# Story: S001-product-crud

## Como
Vendedor

## Quiero
Crear, ver, actualizar y eliminar productos

## Para
Mantener mi catálogo actualizado

## Criterios de Aceptación
[Lista de ACs]

## Tareas
- T001
- T002
- T003

## Estimación
8 story points
```

### Tarea Técnica (Technical Task)

**¿Qué es?**
Trabajo técnico específico para implementar una historia.

**Tamaño:** 1-8 horas

**Ejemplos:**
- "Implementar Product Domain Model"
- "Crear ProductRepository con R2DBC"
- "Agregar endpoint POST /api/products"

**Estructura:**
```markdown
# Task: T001-product-domain

## Descripción
[Qué hacer]

## Alcance Técnico
[Checklist detallado]

## Archivos
[Lista de archivos a crear/modificar]

## Tests
[Lista de tests requeridos]

## Estimación
3-4 horas
```

### Comparación

| Aspecto | Épica | Historia | Tarea |
|---------|-------|----------|-------|
| **Perspectiva** | Negocio (estratégica) | Usuario | Técnica |
| **Duración** | 1-3 meses | 2-5 días | 2-8 horas |
| **Tamaño** | 20-100 SP | 3-13 SP | N/A (horas) |
| **Commits** | Muchos | Varios | 1-3 |
| **PRs** | Muchos | 3-8 | 1 |
| **Quién escribe** | Product Owner | PO + Equipo | Desarrolladores |
| **Ejemplo** | "Catalog Context" | "Product CRUD" | "Product Domain Model" |

---

## Ejemplo Práctico: Implementar Identity Context

### Paso 1: Crear Épica

```bash
cd .specify/epics
# Crear E002-identity-context.md
```

```markdown
# Epic: Identity Context Implementation

## Objetivo
Implementar autenticación y autorización de usuarios.

## Historias
- S005: User Registration
- S006: User Login
- S007: JWT Token Management
- S008: Role-based Access Control

## Estimación
32 story points, 2 sprints
```

### Paso 2: Crear Historia S005

```bash
cd .specify/stories
# Crear S005-user-registration.md
```

```markdown
# Story: User Registration

## Como
Usuario nuevo

## Quiero
Registrarme con email y contraseña

## Para
Poder acceder al sistema

## Criterios de Aceptación
- [ ] AC1: Puedo registrarme con email único
- [ ] AC2: La contraseña se hashea con bcrypt
- [ ] AC3: Se envía email de confirmación
- [ ] AC4: No puedo usar email duplicado

## Tareas
- T006: Implement User Domain Model
- T007: Implement User Repository
- T008: Implement RegisterUserUseCase
- T009: Implement Registration API
- T010: Implement Email Service

## Estimación
8 story points
```

### Paso 3: Desglosar en Tareas

**T006: User Domain Model**
```markdown
# Task: Implement User Domain Model

## Alcance
- [ ] UserId (strongly-typed)
- [ ] Email (value object)
- [ ] HashedPassword (value object)
- [ ] User (aggregate root)
- [ ] UserCreated event
- [ ] EmailVerified event

## Estimación: 3h
## PR: 1 PR con ~250 LOC
```

**T007: User Repository**
```markdown
# Task: Implement User Repository

## Alcance
- [ ] UserRepository interface (port)
- [ ] R2dbcUserRepository (adapter)
- [ ] UserMapper
- [ ] Migration V13__identity__users_table

## Estimación: 2h
## PR: 1 PR con ~200 LOC
```

**T008: RegisterUserUseCase**
```markdown
# Task: Implement RegisterUserUseCase

## Alcance
- [ ] RegisterUserCommand
- [ ] RegisterUserUseCase
- [ ] Validar email único
- [ ] Hashear contraseña
- [ ] Publicar UserCreated event

## Estimación: 2h
## PR: 1 PR con ~150 LOC
```

**T009: Registration API**
```markdown
# Task: Implement Registration API

## Alcance
- [ ] POST /api/auth/register endpoint
- [ ] RegisterRequest DTO
- [ ] RegisterResponse DTO
- [ ] Validaciones de input

## Estimación: 2h
## PR: 1 PR con ~150 LOC
```

**T010: Email Service**
```markdown
# Task: Implement Email Service

## Alcance
- [ ] EmailService port
- [ ] SmtpEmailService adapter
- [ ] Email templates
- [ ] Event handler para UserCreated

## Estimación: 3h
## PR: 1 PR con ~200 LOC
```

### Paso 4: Implementar con Claude

```
Día 1:
09:00 - Le pides a Claude: "Implementa T006"
11:00 - Claude termina, revisas, apruebas PR
11:30 - Le pides a Claude: "Implementa T007"
13:00 - Claude termina, revisas, apruebas PR

Día 2:
09:00 - Le pides a Claude: "Implementa T008"
10:30 - Claude termina, revisas, apruebas PR
11:00 - Le pides a Claude: "Implementa T009"
12:30 - Claude termina, revisas, apruebas PR

Día 3:
09:00 - Le pides a Claude: "Implementa T010"
11:30 - Claude termina, revisas, apruebas PR
12:00 - S005 completa! 🎉
```

**Resultado:**
- 5 PRs pequeños y revisables
- Cada PR tiene valor independiente
- Si T010 falla, el resto sigue funcionando
- Historia completa en 3 días

---

## PRs Atómicos y de Valor

### Principios de un Buen PR

1. **Atómico** - Una sola cosa bien hecha
2. **De Valor** - Aporta funcionalidad o mejora
3. **Independiente** - Puede mergearse sin depender de otros PRs
4. **Pequeño** - Máximo 400 LOC de cambios
5. **Testeado** - Incluye tests que pasan
6. **Documentado** - Actualiza docs si es necesario

### Estrategias de División

#### Estrategia 1: Por Capa (Vertical Slice)

```
PR #1: Domain Layer
├── User.kt
├── UserId.kt
└── UserTest.kt

PR #2: Repository Layer
├── UserRepository.kt (port)
├── R2dbcUserRepository.kt (adapter)
└── UserRepositoryTest.kt

PR #3: Application Layer
├── RegisterUserUseCase.kt
├── RegisterUserCommand.kt
└── RegisterUserUseCaseTest.kt

PR #4: API Layer
├── AuthController.kt
└── AuthControllerTest.kt
```

#### Estrategia 2: Por Feature (Horizontal Slice)

```
PR #1: User Registration (happy path)
├── Domain: User, Email, HashedPassword
├── Application: RegisterUserUseCase
├── Infrastructure: UserRepository, AuthController
└── Tests

PR #2: Email Verification
├── Domain: EmailVerificationToken
├── Application: VerifyEmailUseCase
├── Infrastructure: Email service
└── Tests

PR #3: Password Reset
├── Domain: PasswordResetToken
├── Application: ResetPasswordUseCase
└── Tests
```

#### ¿Cuál usar?

**Vertical Slice (por capa):** Mejor cuando el equipo es grande y varios desarrolladores trabajan en paralelo.

**Horizontal Slice (por feature):** Mejor para equipos pequeños o cuando trabajas solo con Claude.

**Recomendación para ti:** Vertical Slice + Tareas pequeñas

### Ejemplo de Buenos PRs

#### PR #1: Domain Model ✅

```
Title: feat(identity): implement user domain model (T006)

Description:
Implementa el modelo de dominio User como aggregate root.

Changes:
- Add User aggregate root
- Add UserId strongly-typed ID
- Add Email value object
- Add HashedPassword value object
- Add UserCreated domain event
- Add 8 unit tests

Closes: T006
Part of: S005 (User Registration)
Epic: E002 (Identity Context)

Files changed: 6
Lines added: 320
Lines deleted: 0
```

#### PR #2: Repository ✅

```
Title: feat(identity): implement user repository (T007)

Description:
Implementa persistencia para User usando R2DBC.

Changes:
- Add UserRepository port (interface)
- Add R2dbcUserRepository adapter
- Add UserMapper for domain ↔ DB mapping
- Add migration V13__identity__users_table.sql
- Add integration tests

Closes: T007
Part of: S005 (User Registration)
Epic: E002 (Identity Context)
Depends on: PR #1

Files changed: 5
Lines added: 280
Lines deleted: 0
```

### Checklist antes de Crear PR

- [ ] Los tests pasan localmente
- [ ] El código sigue las convenciones del proyecto
- [ ] No hay TODOs o FIXMEs
- [ ] El PR tiene menos de 400 LOC
- [ ] El título sigue el formato: `type(scope): description (task-id)`
- [ ] La descripción explica el QUÉ y el POR QUÉ
- [ ] Está linkeado a la tarea correspondiente
- [ ] Los commits son descriptivos

---

## Mejores Prácticas

### 1. Define ANTES de Implementar

```
❌ MAL:
"Claude, implementa el módulo de usuarios"

✅ BIEN:
1. Escribir E002-identity-context.md
2. Escribir S005-user-registration.md
3. Escribir T006, T007, T008, T009, T010
4. "Claude, implementa T006 según la especificación"
```

### 2. Una Tarea = Un PR

```
✅ Cada tarea genera exactamente 1 PR
✅ Cada PR cierra exactamente 1 tarea
✅ PRs se pueden mergear independientemente
```

### 3. Actualiza las Specs

Cuando una tarea se completa:

```markdown
# Task: T006-user-domain

## Status
✅ COMPLETED

## Implementación
- Committed in: abc123f
- PR: #42
- Merged: 2025-01-10

## Notas
- Se agregó validación extra para email
- Se decidió usar bcrypt con cost factor 12
```

### 4. Mantén el Context Map Actualizado

```markdown
# .specify/context-map.md

## Bounded Contexts Implementados

### ✅ Catalog Context (E001)
- [x] S001: Product CRUD
- [x] S002: Category Management
- [ ] S003: Inventory Management (en progreso)

### 🚧 Identity Context (E002)
- [x] S005: User Registration
- [ ] S006: User Login (next)
- [ ] S007: JWT Management
```

### 5. Usa Convenciones de Naming

```
Épicas:   E001, E002, E003...
Historias: S001, S002, S003...
Tareas:   T001, T002, T003...

Commits:  feat(catalog): implement product domain (T001)
PRs:      feat(identity): user repository (T007)
Branches: feature/T007-user-repository
```

### 6. Review Checklist para Claude

Cuando Claude termine una tarea, revisa:

- [ ] ¿Siguió la especificación de la tarea?
- [ ] ¿El código sigue Hexagonal + DDD?
- [ ] ¿Los tests pasan?
- [ ] ¿El commit message es correcto?
- [ ] ¿Se actualizó el status de la tarea?
- [ ] ¿El PR es atómico y de valor?

---

## Comandos Útiles

### Specify CLI

```bash
# Inicializar
specify init

# Crear épica
specify epic create "Catalog Context"

# Crear historia
specify story create "Product CRUD" --epic E001

# Crear tarea
specify task create "Product Domain Model" --story S001

# Ver status
specify status

# Generar reporte
specify report
```

### Git Workflow

```bash
# Crear branch para tarea
git checkout -b feature/T006-user-domain

# Dejar que Claude implemente...

# Revisar cambios
git diff
git log -1 --stat

# Si todo está bien
git push origin feature/T006-user-domain

# Crear PR (Claude puede hacerlo por ti)
gh pr create --title "feat(identity): user domain (T006)" \
  --body "Implements user domain model. Closes T006"
```

---

## Resumen Ejecutivo

### Tu Workflow Ideal

```
1. PLANIFICAR (1-2 horas)
   └─ Crear épica → historias → tareas en Specify

2. IMPLEMENTAR (con Claude, 30min - 2h por tarea)
   └─ "Claude, implementa T001"
   └─ Claude lee spec, implementa, testea, commitea
   └─ Revisas y apruebas

3. PR (5-10 min por tarea)
   └─ Crear PR pequeño (1 tarea = 1 PR)
   └─ Review rápido
   └─ Merge

4. REPETIR
   └─ T002, T003, T004...
```

### Beneficios

✅ **PRs pequeños** - 150-400 LOC en lugar de 5000 LOC
✅ **Revisiones rápidas** - 10 min en lugar de 2 horas
✅ **Menos conflictos** - Cambios frecuentes y pequeños
✅ **Deploy continuo** - Puedes deployar después de cada PR
✅ **Trazabilidad completa** - Código → Task → Story → Epic
✅ **Trabajo paralelo** - Otros devs pueden trabajar en otras tareas
✅ **Mejor calidad** - Reviews más detalladas en PRs pequeños

### Próximos Pasos

1. **Lee esta guía** (ya lo estás haciendo ✅)
2. **Crea tu primera épica** - E002: Identity Context
3. **Descompón en historias** - S005, S006, S007, S008
4. **Descompón S005 en tareas** - T006-T010
5. **Pide a Claude que implemente T006**
6. **Revisa y aprende del proceso**
7. **Repite con T007, T008...**

---

## Ejemplo Completo de Sesión

```
Tú: "Voy a implementar el Identity Context. Ayúdame a planificarlo."

Claude: "Perfecto. Vamos a crear:
- Épica E002: Identity Context
- Historias: S005 (Registration), S006 (Login), S007 (JWT), S008 (RBAC)
- Tareas para S005: T006-T010

¿Quieres que cree las especificaciones?"

Tú: "Sí, créalas siguiendo el formato de Specify."

Claude: [Crea E002.md, S005.md, T006.md-T010.md]

Tú: "Perfecto. Ahora implementa T006: User Domain Model."

Claude:
1. Lee T006-user-domain.md
2. Lee docs/HEXAGONAL-ARCHITECTURE.md
3. Implementa:
   - UserId.kt
   - Email.kt
   - HashedPassword.kt
   - User.kt
   - UserCreated.kt
   - UserTest.kt
4. Ejecuta tests ✅
5. Commit: "feat(identity): implement user domain (T006)"
6. Actualiza T006.md → COMPLETED

"Implementación completa. 6 archivos creados, 320 LOC, 8 tests pasando."

Tú: [Revisas el código]

Tú: "Perfecto. Crea el PR."

Claude: [Crea PR #42 con descripción completa]

Tú: [Apruebas y mergeas PR #42]

Tú: "Ahora implementa T007: User Repository."

Claude: [Repite el proceso...]
```

---

**Tiempo estimado de lectura: 25-30 minutos**
**Tiempo para dominar el workflow: 2-3 días de práctica**
