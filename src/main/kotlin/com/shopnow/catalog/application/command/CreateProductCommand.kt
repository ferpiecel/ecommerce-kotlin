package com.shopnow.catalog.application.command

import java.util.*

/**
 * Create Product Command
 *
 * Command object for creating a new product.
 */
data class CreateProductCommand(
    val sku: String,
    val name: String,
    val description: String?,
    val price: Double,
    val currency: String = "USD",
    val initialStock: Int,
    val categoryId: UUID,
    val slug: String
)
