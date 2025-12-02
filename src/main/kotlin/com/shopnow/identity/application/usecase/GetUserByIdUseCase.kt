package com.shopnow.identity.application.usecase

import com.shopnow.identity.application.dto.UserDTO
import com.shopnow.identity.domain.repository.UserRepository
import com.shopnow.shared.kernel.domain.NotFoundException
import org.springframework.stereotype.Service
import java.util.*

/**
 * Get User By ID Use Case
 *
 * Retrieves a user by their unique identifier.
 */
@Service
class GetUserByIdUseCase(
    private val userRepository: UserRepository
) {
    suspend fun execute(userId: UUID): UserDTO {
        val user = userRepository.findById(userId)
            ?: throw NotFoundException("User", userId)

        return UserDTO.fromDomain(user)
    }
}
