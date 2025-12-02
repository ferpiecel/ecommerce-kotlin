package com.shopnow.identity.application.usecase

import com.shopnow.identity.domain.repository.UserRepository
import com.shopnow.shared.kernel.domain.NotFoundException
import org.springframework.stereotype.Service
import java.util.*

/**
 * Deactivate User Use Case
 *
 * Deactivates a user account.
 */
@Service
class DeactivateUserUseCase(
    private val userRepository: UserRepository
) {
    suspend fun execute(userId: UUID) {
        val user = userRepository.findById(userId)
            ?: throw NotFoundException("User", userId)

        user.deactivate()
        userRepository.save(user)
    }
}
