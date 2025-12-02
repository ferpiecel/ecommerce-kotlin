package com.shopnow.shared.kernel.domain

/**
 * Base Domain Exception
 */
abstract class DomainException(
    message: String,
    cause: Throwable? = null
) : RuntimeException(message, cause)

/**
 * Entity Not Found Exception
 */
class EntityNotFoundException(
    entityType: String,
    entityId: Any
) : DomainException("$entityType with id $entityId not found")

/**
 * Not Found Exception
 * Generic exception for when a resource is not found
 */
class NotFoundException(
    entityType: String,
    entityId: Any
) : DomainException("$entityType with id $entityId not found")

/**
 * Business Rule Violation Exception
 */
class BusinessRuleViolationException(
    rule: String,
    reason: String
) : DomainException("Business rule '$rule' violated: $reason")

/**
 * Invalid State Exception
 */
class InvalidStateException(
    currentState: String,
    operation: String
) : DomainException("Cannot perform operation '$operation' in state '$currentState'")

/**
 * Insufficient Stock Exception
 */
class InsufficientStockException(
    productId: Any,
    requested: Int,
    available: Int
) : DomainException("Insufficient stock for product $productId. Requested: $requested, Available: $available")
