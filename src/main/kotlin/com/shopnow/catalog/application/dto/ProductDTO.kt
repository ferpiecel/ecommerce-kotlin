package com.shopnow.catalog.application.dto

import java.util.*

/**
 * Product Data Transfer Object
 *
 * Used for read operations (queries).
 */
data class ProductDTO(
    val id: UUID,
    val sku: String,
    val name: String,
    val description: String?,
    val price: Double,
    val currency: String,
    val stockQuantity: Int,
    val categoryId: UUID,
    val slug: String,
    val isActive: Boolean,
    val isFeatured: Boolean
)
