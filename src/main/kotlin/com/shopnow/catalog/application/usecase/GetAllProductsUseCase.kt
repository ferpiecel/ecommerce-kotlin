package com.shopnow.catalog.application.usecase

import com.shopnow.catalog.application.dto.ProductDTO
import com.shopnow.catalog.domain.repository.ProductRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.springframework.stereotype.Service

/**
 * Get All Products Use Case
 *
 * Application service for retrieving all products with pagination.
 */
@Service
class GetAllProductsUseCase(
    private val productRepository: ProductRepository
) {
    suspend fun execute(page: Int = 0, size: Int = 20): Flow<ProductDTO> {
        return productRepository.findAll(page, size)
            .map { product ->
                ProductDTO(
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
}
