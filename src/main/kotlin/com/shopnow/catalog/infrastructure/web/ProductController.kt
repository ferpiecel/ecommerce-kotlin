package com.shopnow.catalog.infrastructure.web

import com.shopnow.catalog.application.command.CreateProductCommand
import com.shopnow.catalog.application.dto.ProductDTO
import com.shopnow.catalog.application.usecase.CreateProductUseCase
import com.shopnow.catalog.application.usecase.GetAllProductsUseCase
import com.shopnow.catalog.application.usecase.GetProductByIdUseCase
import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import kotlinx.coroutines.flow.Flow
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import java.net.URI
import java.util.*

/**
 * Product REST Controller
 *
 * Input adapter that exposes product endpoints via HTTP.
 * Follows hexagonal architecture principles.
 */
@RestController
@RequestMapping("/api/products")
@Tag(name = "Products", description = "Product Catalog Management")
class ProductController(
    private val createProductUseCase: CreateProductUseCase,
    private val getAllProductsUseCase: GetAllProductsUseCase,
    private val getProductByIdUseCase: GetProductByIdUseCase
) {

    @GetMapping
    @Operation(summary = "Get all products", description = "Retrieves all products with pagination")
    suspend fun getAllProducts(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int
    ): Flow<ProductDTO> {
        return getAllProductsUseCase.execute(page, size)
    }

    @PostMapping
    @Operation(summary = "Create a new product", description = "Creates a new product in the catalog")
    suspend fun createProduct(@RequestBody request: CreateProductRequest): ResponseEntity<CreateProductResponse> {
        val command = CreateProductCommand(
            sku = request.sku,
            name = request.name,
            description = request.description,
            price = request.price,
            currency = request.currency,
            initialStock = request.initialStock,
            categoryId = request.categoryId,
            slug = request.slug
        )

        val productId = createProductUseCase.execute(command)

        return ResponseEntity
            .created(URI.create("/api/products/$productId"))
            .body(CreateProductResponse(productId))
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get product by ID", description = "Retrieves a product by its unique identifier")
    suspend fun getProductById(@PathVariable id: UUID): ResponseEntity<ProductDTO> {
        val product = getProductByIdUseCase.execute(id)
        return ResponseEntity.ok(product)
    }
}

// Request/Response DTOs
data class CreateProductRequest(
    val sku: String,
    val name: String,
    val description: String?,
    val price: Double,
    val currency: String = "USD",
    val initialStock: Int,
    val categoryId: UUID,
    val slug: String
)

data class CreateProductResponse(
    val id: UUID
)
