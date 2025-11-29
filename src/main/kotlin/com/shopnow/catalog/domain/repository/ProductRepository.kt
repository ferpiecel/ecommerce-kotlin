package com.shopnow.catalog.domain.repository

import com.shopnow.catalog.domain.model.Product
import kotlinx.coroutines.flow.Flow
import java.util.*

/**
 * Product Repository Port (Interface)
 *
 * Defines the contract for product persistence.
 * This is a port in hexagonal architecture - implementations are adapters.
 */
interface ProductRepository {
    suspend fun save(product: Product): Product
    suspend fun findById(id: UUID): Product?
    suspend fun findBySku(sku: String): Product?
    suspend fun findBySlug(slug: String): Product?
    suspend fun findAll(page: Int = 0, size: Int = 20): Flow<Product>
    suspend fun findByCategory(categoryId: UUID, page: Int = 0, size: Int = 20): Flow<Product>
    suspend fun findFeatured(page: Int = 0, size: Int = 20): Flow<Product>
    suspend fun searchByName(query: String, page: Int = 0, size: Int = 20): Flow<Product>
    suspend fun delete(id: UUID)
    suspend fun existsBySku(sku: String): Boolean
    suspend fun existsBySlug(slug: String): Boolean
}
