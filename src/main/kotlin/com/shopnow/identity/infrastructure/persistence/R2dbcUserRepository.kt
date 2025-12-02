package com.shopnow.identity.infrastructure.persistence

import com.shopnow.identity.domain.model.Email
import com.shopnow.identity.domain.model.Password
import com.shopnow.identity.domain.model.User
import com.shopnow.identity.domain.model.UserStatus
import com.shopnow.identity.domain.repository.UserRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.reactive.asFlow
import kotlinx.coroutines.reactive.awaitFirstOrNull
import org.springframework.r2dbc.core.DatabaseClient
import org.springframework.r2dbc.core.awaitRowsUpdated
import org.springframework.stereotype.Repository
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.*

/**
 * R2DBC User Repository Implementation
 *
 * Adapter that implements the UserRepository port using R2DBC.
 */
@Repository
class R2dbcUserRepository(
    private val databaseClient: DatabaseClient
) : UserRepository {

    override suspend fun save(user: User): User {
        val sql = """
            INSERT INTO identity.users (
                id, username, email, password_hash, first_name, last_name, 
                date_of_birth, phone_number, status, email_verified, phone_verified, 
                registered_at, last_login_at, failed_login_attempts, locked_until
            )
            VALUES (
                :id, :username, :email, :passwordHash, :firstName, :lastName,
                :dateOfBirth, :phoneNumber, :status, :emailVerified, :phoneVerified,
                :registeredAt, :lastLoginAt, :failedLoginAttempts, :lockedUntil
            )
            ON CONFLICT (id) DO UPDATE SET
                username = EXCLUDED.username,
                email = EXCLUDED.email,
                password_hash = EXCLUDED.password_hash,
                first_name = EXCLUDED.first_name,
                last_name = EXCLUDED.last_name,
                date_of_birth = EXCLUDED.date_of_birth,
                phone_number = EXCLUDED.phone_number,
                status = EXCLUDED.status,
                email_verified = EXCLUDED.email_verified,
                phone_verified = EXCLUDED.phone_verified,
                last_login_at = EXCLUDED.last_login_at,
                failed_login_attempts = EXCLUDED.failed_login_attempts,
                locked_until = EXCLUDED.locked_until,
                updated_at = CURRENT_TIMESTAMP
        """.trimIndent()

        var spec = databaseClient.sql(sql)
            .bind("id", user.id)
            .bind("username", user.username)
            .bind("email", user.email.value)
            .bind("passwordHash", user.password.hash)
            .bind("status", user.status.name)
            .bind("emailVerified", user.emailVerified)
            .bind("phoneVerified", user.phoneVerified)
            .bind("registeredAt", user.registeredAt)
            .bind("failedLoginAttempts", user.failedLoginAttempts)

        // Handle nullable fields
        spec = bindNullable(spec, "firstName", user.firstName)
        spec = bindNullable(spec, "lastName", user.lastName)
        spec = bindNullable(spec, "dateOfBirth", user.dateOfBirth)
        spec = bindNullable(spec, "phoneNumber", user.phoneNumber)
        spec = bindNullable(spec, "lastLoginAt", user.lastLoginAt)
        spec = bindNullable(spec, "lockedUntil", user.lockedUntil)

        spec.fetch().awaitRowsUpdated()
        return user
    }

    override suspend fun findById(id: UUID): User? {
        val sql = """
            SELECT id, username, email, password_hash, first_name, last_name,
                   date_of_birth, phone_number, status, email_verified, phone_verified,
                   registered_at, last_login_at, failed_login_attempts, locked_until
            FROM identity.users
            WHERE id = :id
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("id", id)
            .fetch()
            .one()
            .map { row -> mapToUser(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findByUsername(username: String): User? {
        val sql = """
            SELECT id, username, email, password_hash, first_name, last_name,
                   date_of_birth, phone_number, status, email_verified, phone_verified,
                   registered_at, last_login_at, failed_login_attempts, locked_until
            FROM identity.users
            WHERE username = :username
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("username", username)
            .fetch()
            .one()
            .map { row -> mapToUser(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findByEmail(email: String): User? {
        val sql = """
            SELECT id, username, email, password_hash, first_name, last_name,
                   date_of_birth, phone_number, status, email_verified, phone_verified,
                   registered_at, last_login_at, failed_login_attempts, locked_until
            FROM identity.users
            WHERE email = :email
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("email", email.lowercase())
            .fetch()
            .one()
            .map { row -> mapToUser(row) }
            .awaitFirstOrNull()
    }

    override suspend fun findAll(page: Int, size: Int): Flow<User> {
        val offset = page * size
        val sql = """
            SELECT id, username, email, password_hash, first_name, last_name,
                   date_of_birth, phone_number, status, email_verified, phone_verified,
                   registered_at, last_login_at, failed_login_attempts, locked_until
            FROM identity.users
            ORDER BY registered_at DESC
            LIMIT :limit OFFSET :offset
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("limit", size)
            .bind("offset", offset)
            .fetch()
            .all()
            .map { row -> mapToUser(row) }
            .asFlow()
    }

    override suspend fun findByStatus(status: UserStatus, page: Int, size: Int): Flow<User> {
        val offset = page * size
        val sql = """
            SELECT id, username, email, password_hash, first_name, last_name,
                   date_of_birth, phone_number, status, email_verified, phone_verified,
                   registered_at, last_login_at, failed_login_attempts, locked_until
            FROM identity.users
            WHERE status = :status
            ORDER BY registered_at DESC
            LIMIT :limit OFFSET :offset
        """.trimIndent()

        return databaseClient.sql(sql)
            .bind("status", status.name)
            .bind("limit", size)
            .bind("offset", offset)
            .fetch()
            .all()
            .map { row -> mapToUser(row) }
            .asFlow()
    }

    override suspend fun delete(id: UUID) {
        val sql = "DELETE FROM identity.users WHERE id = :id"
        databaseClient.sql(sql)
            .bind("id", id)
            .fetch()
            .awaitRowsUpdated()
    }

    override suspend fun existsByUsername(username: String): Boolean {
        val sql = "SELECT COUNT(*) as count FROM identity.users WHERE username = :username"
        val count = databaseClient.sql(sql)
            .bind("username", username)
            .fetch()
            .one()
            .map { row -> (row["count"] as? Number)?.toLong() ?: 0L }
            .awaitFirstOrNull() ?: 0L
        return count > 0
    }

    override suspend fun existsByEmail(email: String): Boolean {
        val sql = "SELECT COUNT(*) as count FROM identity.users WHERE email = :email"
        val count = databaseClient.sql(sql)
            .bind("email", email.lowercase())
            .fetch()
            .one()
            .map { row -> (row["count"] as? Number)?.toLong() ?: 0L }
            .awaitFirstOrNull() ?: 0L
        return count > 0
    }

    private fun mapToUser(row: Map<String, Any>): User {
        // Using reflection to access private constructor
        val constructor = User::class.java.getDeclaredConstructor(
            UUID::class.java,
            String::class.java,
            Email::class.java,
            Password::class.java,
            String::class.java,
            String::class.java,
            LocalDate::class.java,
            String::class.java,
            UserStatus::class.java,
            Boolean::class.javaPrimitiveType,
            Boolean::class.javaPrimitiveType,
            LocalDateTime::class.java,
            LocalDateTime::class.java,
            Int::class.javaPrimitiveType,
            LocalDateTime::class.java
        )
        constructor.isAccessible = true

        return constructor.newInstance(
            row["id"] as UUID,
            row["username"] as String,
            Email.of(row["email"] as String),
            Password.fromHash(row["password_hash"] as String),
            row["first_name"] as String?,
            row["last_name"] as String?,
            row["date_of_birth"] as LocalDate?,
            row["phone_number"] as String?,
            UserStatus.valueOf(row["status"] as String),
            row["email_verified"] as Boolean,
            row["phone_verified"] as Boolean,
            row["registered_at"] as LocalDateTime,
            row["last_login_at"] as LocalDateTime?,
            (row["failed_login_attempts"] as Number).toInt(),
            row["locked_until"] as LocalDateTime?
        )
    }

    private fun <T> bindNullable(
        spec: DatabaseClient.GenericExecuteSpec,
        paramName: String,
        value: T?
    ): DatabaseClient.GenericExecuteSpec {
        return if (value != null) {
            spec.bind(paramName, value)
        } else {
            when (paramName) {
                "firstName", "lastName", "phoneNumber" -> spec.bindNull(paramName, String::class.java)
                "dateOfBirth" -> spec.bindNull(paramName, LocalDate::class.java)
                "lastLoginAt", "lockedUntil" -> spec.bindNull(paramName, LocalDateTime::class.java)
                else -> spec.bindNull(paramName, Any::class.java)
            }
        }
    }
}
