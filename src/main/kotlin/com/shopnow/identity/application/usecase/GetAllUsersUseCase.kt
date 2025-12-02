package com.shopnow.identity.application.usecase

import com.shopnow.identity.application.dto.UserDTO
import com.shopnow.identity.domain.repository.UserRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import org.springframework.stereotype.Service

/**
 * Get All Users Use Case
 *
 * Retrieves all users with pagination.
 */
@Service
class GetAllUsersUseCase(
    private val userRepository: UserRepository
) {
    suspend fun execute(page: Int = 0, size: Int = 20): Flow<UserDTO> {
        return userRepository.findAll(page, size)
            .map { user -> UserDTO.fromDomain(user) }
    }
}
