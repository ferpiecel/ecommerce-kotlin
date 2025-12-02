package com.shopnow.identity.domain.repository

import com.shopnow.identity.domain.model.User
import com.shopnow.identity.domain.model.UserStatus
import kotlinx.coroutines.flow.Flow
import java.util.*

/**
 * User Repository Port (Interface)
 *
 * Defines the contract for user persistence.
 * This is a port in hexagonal architecture - implementations are adapters.
 */
interface UserRepository {
    suspend fun save(user: User): User
    suspend fun findById(id: UUID): User?
    suspend fun findByUsername(username: String): User?
    suspend fun findByEmail(email: String): User?
    suspend fun findAll(page: Int = 0, size: Int = 20): Flow<User>
    suspend fun findByStatus(status: UserStatus, page: Int = 0, size: Int = 20): Flow<User>
    suspend fun delete(id: UUID)
    suspend fun existsByUsername(username: String): Boolean
    suspend fun existsByEmail(email: String): Boolean
}
