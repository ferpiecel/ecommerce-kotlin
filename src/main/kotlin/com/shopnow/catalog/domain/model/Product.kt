package com.shopnow.catalog.domain.model

import com.shopnow.shared.kernel.domain.AggregateRoot
import com.shopnow.shared.kernel.domain.BaseDomainEvent
import com.shopnow.shared.kernel.domain.InsufficientStockException
import com.shopnow.shared.kernel.domain.valueobject.Money
import java.util.*

/**
 * Product Aggregate Root
 *
 * Represents a product in the catalog with inventory management.
 */
class Product private constructor(
    override val id: UUID,
    var sku: String,
    var name: String,
    var description: String?,
    var price: Money,
    var stockQuantity: Int,
    var categoryId: UUID,
    var slug: String,
    var isActive: Boolean = true,
    var isFeatured: Boolean = false
) : AggregateRoot<UUID>() {

    companion object {
        fun create(
            sku: String,
            name: String,
            description: String?,
            price: Money,
            initialStock: Int,
            categoryId: UUID,
            slug: String
        ): Product {
            require(sku.isNotBlank()) { "SKU cannot be blank" }
            require(name.isNotBlank()) { "Name cannot be blank" }
            require(price.isPositive()) { "Price must be positive" }
            require(initialStock >= 0) { "Initial stock cannot be negative" }
            require(slug.isNotBlank()) { "Slug cannot be blank" }

            val product = Product(
                id = UUID.randomUUID(),
                sku = sku,
                name = name,
                description = description,
                price = price,
                stockQuantity = initialStock,
                categoryId = categoryId,
                slug = slug
            )

            product.registerEvent(ProductCreatedEvent(product.id, sku, name, price))
            return product
        }
    }

    fun changePrice(newPrice: Money) {
        require(newPrice.isPositive()) { "Price must be positive" }
        val oldPrice = price
        price = newPrice
        registerEvent(ProductPriceChangedEvent(id, oldPrice, newPrice))
    }

    fun updateInfo(newName: String, newDescription: String?) {
        require(newName.isNotBlank()) { "Name cannot be blank" }
        name = newName
        description = newDescription
        registerEvent(ProductInfoUpdatedEvent(id, name))
    }

    fun addStock(quantity: Int) {
        require(quantity > 0) { "Quantity must be positive" }
        stockQuantity += quantity
        registerEvent(StockAddedEvent(id, quantity, stockQuantity))
    }

    fun reserveStock(quantity: Int) {
        require(quantity > 0) { "Quantity must be positive" }
        if (stockQuantity < quantity) {
            throw InsufficientStockException(id, quantity, stockQuantity)
        }
        stockQuantity -= quantity
        registerEvent(StockReservedEvent(id, quantity, stockQuantity))
    }

    fun releaseStock(quantity: Int) {
        require(quantity > 0) { "Quantity must be positive" }
        stockQuantity += quantity
        registerEvent(StockReleasedEvent(id, quantity, stockQuantity))
    }

    fun activate() {
        if (!isActive) {
            isActive = true
            registerEvent(ProductActivatedEvent(id))
        }
    }

    fun deactivate() {
        if (isActive) {
            isActive = false
            registerEvent(ProductDeactivatedEvent(id))
        }
    }

    fun markAsFeatured() {
        if (!isFeatured) {
            isFeatured = true
            registerEvent(ProductMarkedAsFeaturedEvent(id))
        }
    }

    fun unmarkAsFeatured() {
        if (isFeatured) {
            isFeatured = false
            registerEvent(ProductUnmarkedAsFeaturedEvent(id))
        }
    }

    fun hasStock(): Boolean = stockQuantity > 0
    fun isInStock(quantity: Int): Boolean = stockQuantity >= quantity
}

// Domain Events
class ProductCreatedEvent(
    aggregateId: UUID,
    val sku: String,
    val name: String,
    val price: Money
) : BaseDomainEvent(aggregateId, "ProductCreated")

class ProductPriceChangedEvent(
    aggregateId: UUID,
    val oldPrice: Money,
    val newPrice: Money
) : BaseDomainEvent(aggregateId, "ProductPriceChanged")

class ProductInfoUpdatedEvent(
    aggregateId: UUID,
    val name: String
) : BaseDomainEvent(aggregateId, "ProductInfoUpdated")

class StockAddedEvent(
    aggregateId: UUID,
    val quantity: Int,
    val newStockLevel: Int
) : BaseDomainEvent(aggregateId, "StockAdded")

class StockReservedEvent(
    aggregateId: UUID,
    val quantity: Int,
    val remainingStock: Int
) : BaseDomainEvent(aggregateId, "StockReserved")

class StockReleasedEvent(
    aggregateId: UUID,
    val quantity: Int,
    val newStockLevel: Int
) : BaseDomainEvent(aggregateId, "StockReleased")

class ProductActivatedEvent(
    aggregateId: UUID
) : BaseDomainEvent(aggregateId, "ProductActivated")

class ProductDeactivatedEvent(
    aggregateId: UUID
) : BaseDomainEvent(aggregateId, "ProductDeactivated")

class ProductMarkedAsFeaturedEvent(
    aggregateId: UUID
) : BaseDomainEvent(aggregateId, "ProductMarkedAsFeatured")

class ProductUnmarkedAsFeaturedEvent(
    aggregateId: UUID
) : BaseDomainEvent(aggregateId, "ProductUnmarkedAsFeatured")
