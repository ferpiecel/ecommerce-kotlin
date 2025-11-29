package com.shopnow.catalog.application.usecase

import com.shopnow.catalog.application.dto.ProductDTO
import com.shopnow.catalog.domain.repository.ProductRepository
import com.shopnow.shared.kernel.domain.EntityNotFoundException
import org.springframework.stereotype.Service
import java.util.*

/**
 * Get Product By ID Use Case
 */
@Service
class GetProductByIdUseCase(
    private val productRepository: ProductRepository
) {
    suspend fun execute(productId: UUID): ProductDTO {
        val product = productRepository.findById(productId)
            ?: throw EntityNotFoundException("Product", productId)

        return ProductDTO(
            id = product.id,
            sku = product.sku,
            name = product.name,
            description = product.description,
            price = product.price.amount.toDouble(),
            currency = product.price.currency.currencyCode,
            stockQuantity = product.stockQuantity,
            categoryId = product.categoryId,
            slug = product.slug,
            isActive = product.isActive,
            isFeatured = product.isFeatured
        )
    }
}
