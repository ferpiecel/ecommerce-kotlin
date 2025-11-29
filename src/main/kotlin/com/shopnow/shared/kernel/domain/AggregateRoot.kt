package com.shopnow.shared.kernel.domain

import java.util.*

/**
 * Aggregate Root base class
 *
 * Represents the root entity of an aggregate in DDD.
 * Aggregates are clusters of domain objects that can be treated as a single unit.
 */
abstract class AggregateRoot<ID : Any> : Entity<ID>() {
    private val domainEvents: MutableList<DomainEvent> = mutableListOf()

    protected fun registerEvent(event: DomainEvent) {
        domainEvents.add(event)
    }

    fun pullDomainEvents(): List<DomainEvent> {
        val events = domainEvents.toList()
        domainEvents.clear()
        return events
    }

    fun clearDomainEvents() {
        domainEvents.clear()
    }
}

/**
 * Entity base class
 */
abstract class Entity<ID : Any> {
    abstract val id: ID

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other == null || this::class != other::class) return false
        other as Entity<*>
        return id == other.id
    }

    override fun hashCode(): Int = id.hashCode()
}

/**
 * Domain Event interface
 */
interface DomainEvent {
    val eventId: UUID
    val occurredAt: java.time.Instant
    val aggregateId: UUID
    val eventType: String
}

/**
 * Base Domain Event
 */
abstract class BaseDomainEvent(
    override val aggregateId: UUID,
    override val eventType: String
) : DomainEvent {
    override val eventId: UUID = UUID.randomUUID()
    override val occurredAt: java.time.Instant = java.time.Instant.now()
}
