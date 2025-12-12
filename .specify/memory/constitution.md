<!--
Sync Impact Report - Constitution Update
Version: 0.0.0 → 1.0.0 (Initial Constitution)
Date: 2025-12-12

Modified Principles:
  - NEW: I. Domain-Driven Design (DDD)
  - NEW: II. Hexagonal Architecture (Ports & Adapters)
  - NEW: III. Reactive-First Development
  - NEW: IV. Domain Purity (NON-NEGOTIABLE)
  - NEW: V. Bounded Contexts & Schema Isolation
  - NEW: VI. Event-Driven Communication
  - NEW: VII. Test-Driven Development

Added Sections:
  - Architectural Constraints
  - Development Workflow

Templates Status:
  ✅ plan-template.md - Compatible (Constitution Check placeholder ready)
  ✅ spec-template.md - Compatible (User Stories align with DDD bounded contexts)
  ✅ tasks-template.md - Compatible (Phase structure supports hexagonal layers)

Follow-up TODOs:
  - None - All placeholders filled
-->

# ShopNow E-Commerce Platform Constitution

## Core Principles

### I. Domain-Driven Design (DDD)

The **domain model is the heart of the system**. All business logic, rules, and behavior MUST reside in the domain layer using the ubiquitous language shared with domain experts.

**Rules:**
- Use **Aggregates** to enforce consistency boundaries (e.g., `Order`, `Product`, `User`)
- Use **Value Objects** for concepts defined by attributes (e.g., `Money`, `Email`, `Address`)
- Use **Domain Events** to represent significant business occurrences (past tense: `OrderConfirmed`, `ProductCreated`)
- Use **Domain Services** for operations spanning multiple aggregates
- Every bounded context MUST have its own ubiquitous language reflected in code

**Rationale:** Software that mirrors the business domain is easier to understand, maintain, and evolve as business requirements change.

### II. Hexagonal Architecture (Ports & Adapters)

The system MUST follow strict **layered separation** with dependency inversion: Infrastructure → Application → Domain.

**Rules:**
- **Domain layer**: Contains only business logic (no framework dependencies)
- **Application layer**: Orchestrates use cases, defines ports (interfaces)
- **Infrastructure layer**: Implements adapters for REST, persistence, messaging, etc.
- All external dependencies MUST go through **ports** (interfaces)
- Domain and Application layers MUST NOT import infrastructure classes

**Rationale:** Isolating the core business logic from external concerns enables technology changes (database, framework, API protocol) without rewriting business rules.

### III. Reactive-First Development

All code paths MUST be **fully reactive** using Kotlin coroutines and Flow to support high concurrency and responsiveness.

**Rules:**
- Use `suspend fun` for single-value asynchronous operations
- Use `Flow<T>` for streaming collections
- Use Spring WebFlux and R2DBC (NEVER blocking JDBC in reactive code)
- Controllers return `suspend fun` or `Flow<T>`
- NEVER mix blocking I/O with reactive code

**Rationale:** Reactive programming enables the system to handle thousands of concurrent users efficiently with non-blocking I/O.

### IV. Domain Purity (NON-NEGOTIABLE)

The domain package (`com.shopnow.<context>/domain/`) MUST remain **100% framework-agnostic**. No Spring, R2DBC, JPA, or any infrastructure annotations allowed.

**Rules:**
- NO `@Entity`, `@Table`, `@Column`, `@Service`, `@Component` in domain classes
- NO Spring or persistence framework imports in domain layer
- Domain objects use **private constructors** + **factory methods** (e.g., `Order.create()`)
- Aggregates expose **behavior**, not setters (e.g., `order.confirm()`, not `order.setStatus()`)
- Repository interfaces defined in domain, implemented in infrastructure

**Rationale:** Domain purity ensures business logic can be tested independently, reused across different frameworks, and evolved without coupling to infrastructure concerns.

### V. Bounded Contexts & Schema Isolation

The system is organized into **10 bounded contexts**, each with its own PostgreSQL schema. Contexts MUST NOT share database tables.

**Bounded Contexts:**
1. `catalog` - Products, categories, inventory
2. `identity` - Users, authentication, authorization
3. `shopping` - Cart, wishlist, reviews
4. `orders` - Order management, lifecycle
5. `payment` - Payment processing, transactions
6. `shipping` - Shipping methods, tracking
7. `promotion` - Discounts, coupons, campaigns
8. `partner` - Affiliates, suppliers
9. `notification` - User notifications, alerts
10. `audit` - Audit logging, activity tracking

**Rules:**
- Each context has its own schema in PostgreSQL
- NEVER join tables across schemas
- Context communication ONLY through domain events or API calls
- Each context has its own: `domain/`, `application/`, `infrastructure/`
- Migration files prefixed: `V{N}__{context}__description.sql`

**Rationale:** Bounded contexts enforce clear boundaries, enable independent evolution, and support future microservice extraction if needed.

### VI. Event-Driven Communication

State changes in aggregates MUST generate **Domain Events** for asynchronous communication between bounded contexts.

**Rules:**
- Events are **immutable records** named in past tense (e.g., `OrderConfirmedEvent`)
- Events include: `eventId`, `occurredAt`, `aggregateId`, `aggregateType`, `eventType`
- Aggregates register events via `registerEvent(event)`
- After saving aggregate: `eventPublisher.publishAll(aggregate.pullDomainEvents())`
- Event handlers are **@Async** and handle events independently

**Rationale:** Event-driven architecture decouples bounded contexts, enables independent scaling, and prevents circular dependencies.

### VII. Test-Driven Development

Tests MUST be written at all three layers: domain (unit), application (integration with mocks), and infrastructure (integration with real DB).

**Rules:**
- **Domain tests**: Pure unit tests, no dependencies, test aggregates and value objects
- **Application tests**: Mock repositories/ports, test use case orchestration
- **Infrastructure tests**: Use Testcontainers for PostgreSQL/Redis, test adapters
- Use Kotest for Kotlin-idiomatic testing, MockK for mocking
- Test coverage expected: Domain > 90%, Application > 80%, Infrastructure > 70%

**Rationale:** Multi-layer testing ensures business logic correctness (domain), workflow orchestration (application), and integration reliability (infrastructure).

## Architectural Constraints

### Repository Pattern

**Rule:** All persistence MUST go through repository interfaces defined in domain, implemented in infrastructure using R2DBC.

**Implementation:**
- Interface in `domain/repository/` (e.g., `OrderRepository`)
- Implementation in `infrastructure/persistence/` (e.g., `R2DBCOrderRepository`)
- Use `DatabaseClient` for reactive queries
- Repositories reconstruct aggregates using reflection to preserve private constructors

### Value Objects

**Rule:** Use Kotlin `data class` or Java records for immutable, self-validating value objects.

**Requirements:**
- Immutable (all properties `val`)
- Self-validating in constructor (throw exception if invalid)
- Examples: `Money`, `Email`, `Address`, `Password`
- Equality by value, not identity

### Factory Methods

**Rule:** Aggregates MUST use private constructors with static factory methods for creation.

**Pattern:**
```kotlin
class Order private constructor(...) {
    companion object {
        fun create(customerId: CustomerId): Order {
            val order = Order(...)
            order.registerEvent(OrderCreatedEvent(...))
            return order
        }
    }
}
```

### Database Migrations

**Rule:** Use Flyway for schema migrations with strict naming convention.

**Naming:** `V{number}__{context}__{description}.sql`

**Examples:**
- `V1__create_all_schemas.sql`
- `V2__catalog__create_tables.sql`
- `V3__identity__create_tables.sql`

**Requirements:**
- Always prefix table names with schema (e.g., `catalog.products`)
- Never cross-reference tables across schemas

## Development Workflow

### Feature Development Process

1. **Specification**: Create feature spec using `/speckit.specify`
2. **Planning**: Generate implementation plan using `/speckit.plan`
3. **Task Generation**: Create tasks using `/speckit.tasks`
4. **Implementation**: Follow TDD for each layer:
   - Write tests (domain → application → infrastructure)
   - Implement to make tests pass
   - Refactor while keeping tests green
5. **Migration**: Create Flyway migration if schema changes needed
6. **Documentation**: Update relevant docs in `docs/`

### Code Structure Per Bounded Context

```
com.shopnow.<context>/
├── domain/              # Core business logic (no framework dependencies)
│   ├── model/          # Aggregates, Entities, Value Objects
│   ├── repository/     # Repository interfaces (ports)
│   ├── event/          # Domain events
│   └── service/        # Domain services
├── application/         # Use cases and orchestration
│   ├── usecase/        # Application services
│   ├── command/        # Command objects
│   └── dto/           # Data Transfer Objects
└── infrastructure/      # Framework and external concerns
    ├── web/           # REST controllers (input adapters)
    └── persistence/   # Repository implementations (output adapters)
```

### Anti-Patterns to Avoid

**Anemic Domain Model:**
- ❌ BAD: `order.setStatus("CONFIRMED")`
- ✅ GOOD: `order.confirm()`

**Framework Leakage:**
- ❌ BAD: `@Entity` in domain layer
- ✅ GOOD: Clean domain, `@Table` only in infrastructure entities

**Direct DB Access:**
- ❌ BAD: Use `EntityManager` in application service
- ✅ GOOD: Use `OrderRepository` interface

**Cross-Context Joins:**
- ❌ BAD: JOIN `catalog.products` with `orders.order_items` across schemas
- ✅ GOOD: Use events or API calls between contexts

## Governance

### Constitution Enforcement

- All feature specifications MUST include a "Constitution Check" section
- Code reviews MUST verify compliance with all 7 core principles
- Violations MUST be justified in the "Complexity Tracking" section of plan.md
- Architecture Decision Records (ADRs) required for principle deviations

### Amendment Process

1. Propose amendment with rationale and impact analysis
2. Update affected templates (plan, spec, tasks)
3. Increment version following semantic versioning:
   - **MAJOR**: Backward-incompatible principle changes
   - **MINOR**: New principles or significant expansions
   - **PATCH**: Clarifications, typo fixes, non-semantic changes
4. Document migration path for existing features
5. Update `LAST_AMENDED_DATE`

### Versioning Policy

- Version format: `MAJOR.MINOR.PATCH`
- All changes tracked in Sync Impact Report (HTML comment at top of file)
- Breaking changes require migration guide for existing code

### Compliance Review

- Constitution review during planning phase (before implementation)
- Architecture review during code review (during implementation)
- Retrospective analysis (after feature completion)

### Runtime Guidance

For detailed implementation guidance during development, refer to:
- `CLAUDE.md` - Claude Code agent instructions
- `docs/Arquitectura-hexagonal-parte1.md` through `parte5.md` - Architecture guide
- `.specify/templates/` - Speckit workflow templates

**Version**: 1.0.0 | **Ratified**: 2025-12-12 | **Last Amended**: 2025-12-12
