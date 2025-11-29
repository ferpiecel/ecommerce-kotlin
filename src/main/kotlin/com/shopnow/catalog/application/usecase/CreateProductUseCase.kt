package com.shopnow.catalog.application.usecase

import com.shopnow.catalog.application.command.CreateProductCommand
import com.shopnow.catalog.domain.model.Product
import com.shopnow.catalog.domain.repository.ProductRepository
import com.shopnow.shared.kernel.domain.BusinessRuleViolationException
import com.shopnow.shared.kernel.domain.valueobject.Money
import org.springframework.stereotype.Service
import java.util.*

/**
 * Create Product Use Case
 *
 * Application service that orchestrates product creation.
 */
@Service
class CreateProductUseCase(
    private val productRepository: ProductRepository
) {
    suspend fun execute(command: CreateProductCommand): UUID {
        // Business rule: SKU must be unique
        if (productRepository.existsBySku(command.sku)) {
            throw BusinessRuleViolationException(
                "UniqueSKU",
                "Product with SKU '${command.sku}' already exists"
            )
        }

        // Business rule: Slug must be unique
        if (productRepository.existsBySlug(command.slug)) {
            throw BusinessRuleViolationException(
                "UniqueSlug",
                "Product with slug '${command.slug}' already exists"
            )
        }

        val price = Money.of(command.price, command.currency)

        val product = Product.create(
            sku = command.sku,
            name = command.name,
            description = command.description,
            price = price,
            initialStock = command.initialStock,
            categoryId = command.categoryId,
            slug = command.slug
        )

        val savedProduct = productRepository.save(product)

        // Domain events will be published by infrastructure layer
        return savedProduct.id
    }
}
