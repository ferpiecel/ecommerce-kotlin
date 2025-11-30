package com.shopnow.catalog.infrastructure.persistence

import com.shopnow.catalog.domain.model.Product
import com.shopnow.catalog.domain.repository.ProductRepository
import com.shopnow.shared.kernel.domain.valueobject.Money
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.reactive.asFlow
import kotlinx.coroutines.reactive.awaitFirstOrNull
import org.springframework.r2dbc.core.DatabaseClient
import org.springframework.r2dbc.core.awaitRowsUpdated
import org.springframework.stereotype.Repository
import java.math.BigDecimal
import java.util.*

/**
 * R2DBC Product Repository Implementation
 *
 * Adapter that implements the ProductRepository port using R2DBC.
 */
@Repository
class R2dbcProductRepository(
    private val databaseClient: DatabaseClient
) : ProductRepository {

    override suspend fun save(product: Product): Product {
        val sql = """
            INSERT INTO catalog.products (id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured)
            VALUES (:id, :sku, :name, :description, :price, :currency, :stockQuantity, :categoryId, :slug, :isActive, :isFeatured)
            ON CONFLICT (id) DO UPDATE SET
                sku = EXCLUDED.sku,
                name = EXCLUDED.name,
                description = EXCLUDED.description,
                price = EXCLUDED.price,
                currency = EXCLUDED.currency,
                stock_quantity = EXCLUDED.stock_quantity,
                category_id = EXCLUDED.category_id,
                slug = EXCLUDED.slug,
                is_active = EXCLUDED.is_active,
                is_featured = EXCLUDED.is_featured,
                updated_at = CURRENT_TIMESTAMP
        """.trimIndent()

        var spec = databaseClient.sql(sql)
            .bind("id", product.id)
            .bind("sku", product.sku)
            .bind("name", product.name)
            .bind("price", product.price.amount)
            .bind("currency", product.price.currency.currencyCode)
            .bind("stockQuantity", product.stockQuantity)
            .bind("categoryId", product.categoryId)
            .bind("slug", product.slug)
            .bind("isActive", product.isActive)
            .bind("isFeatured", product.isFeatured)

        // Handle nullable description
        val desc = product.description
        spec = if (desc != null) {
            spec.bind("description", desc)
        } else {
            spec.bindNull("description", String::class.java)
        }

        spec.fetch().awaitRowsUpdated()
        return product
    }

    override suspend fun findById(id: UUID): Product? {
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            WHERE id = :id
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("id", id)
            .fetch()
            .one()
            .map { row -> mapToProduct(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findBySku(sku: String): Product? {
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            WHERE sku = :sku
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("sku", sku)
            .fetch()
            .one()
            .map { row -> mapToProduct(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findBySlug(slug: String): Product? {
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            WHERE slug = :slug
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("slug", slug)
            .fetch()
            .one()
            .map { row -> mapToProduct(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findAll(page: Int, size: Int): Flow<Product> {
        val offset = page * size
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("limit", size)
            .bind("offset", offset)
            .fetch()
            .all()
            .map { row -> mapToProduct(row) }
            .asFlow()
    }

    override suspend fun findByCategory(categoryId: UUID, page: Int, size: Int): Flow<Product> {
        val offset = page * size
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            WHERE category_id = :categoryId AND is_active = true
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("categoryId", categoryId)
            .bind("limit", size)
            .bind("offset", offset)
            .fetch()
            .all()
            .map { row -> mapToProduct(row) }
            .asFlow()
    }

    override suspend fun findFeatured(page: Int, size: Int): Flow<Product> {
        val offset = page * size
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            WHERE is_featured = true AND is_active = true
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("limit", size)
            .bind("offset", offset)
            .fetch()
            .all()
            .map { row -> mapToProduct(row) }
            .asFlow()
    }

    override suspend fun searchByName(query: String, page: Int, size: Int): Flow<Product> {
        val offset = page * size
        val sql = """
            SELECT id, sku, name, description, price, currency, stock_quantity, category_id, slug, is_active, is_featured
            FROM catalog.products
            WHERE to_tsvector('english', name) @@ plainto_tsquery('english', :query)
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("query", query)
            .bind("limit", size)
            .bind("offset", offset)
            .fetch()
            .all()
            .map { row -> mapToProduct(row) }
            .asFlow()
    }

    override suspend fun delete(id: UUID) {
        val sql = "DELETE FROM catalog.products WHERE id = :id"
        databaseClient.sql(sql)
            .bind("id", id)
            .fetch()
            .awaitRowsUpdated()
    }

    override suspend fun existsBySku(sku: String): Boolean {
        val sql = "SELECT COUNT(*) as count FROM catalog.products WHERE sku = :sku"
        val count = databaseClient.sql(sql)
            .bind("sku", sku)
            .fetch()
            .one()
            .map { row -> (row["count"] as? Number)?.toLong() ?: 0L }
            .awaitFirstOrNull() ?: 0L
        return count > 0
    }

    override suspend fun existsBySlug(slug: String): Boolean {
        val sql = "SELECT COUNT(*) as count FROM catalog.products WHERE slug = :slug"
        val count = databaseClient.sql(sql)
            .bind("slug", slug)
            .fetch()
            .one()
            .map { row -> (row["count"] as? Number)?.toLong() ?: 0L }
            .awaitFirstOrNull() ?: 0L
        return count > 0
    }

    private fun mapToProduct(row: Map<String, Any>): Product {
        // Using reflection to access private constructor
        val constructor = Product::class.java.getDeclaredConstructor(
            UUID::class.java,
            String::class.java,
            String::class.java,
            String::class.java,
            Money::class.java,
            Int::class.javaPrimitiveType,
            UUID::class.java,
            String::class.java,
            Boolean::class.javaPrimitiveType,
            Boolean::class.javaPrimitiveType
        )
        constructor.isAccessible = true

        return constructor.newInstance(
            row["id"] as UUID,
            row["sku"] as String,
            row["name"] as String,
            row["description"] as String?,
            Money.of(row["price"] as BigDecimal, row["currency"] as String),
            (row["stock_quantity"] as Number).toInt(),
            row["category_id"] as UUID,
            row["slug"] as String,
            row["is_active"] as Boolean,
            row["is_featured"] as Boolean
        )
    }
}
