package com.shopnow.identity.application.usecase

import com.shopnow.identity.domain.repository.UserRepository
import com.shopnow.shared.kernel.domain.NotFoundException
import org.springframework.stereotype.Service
import java.util.*

/**
 * Activate User Use Case
 *
 * Activates a user account.
 */
@Service
class ActivateUserUseCase(
    private val userRepository: UserRepository
) {
    suspend fun execute(userId: UUID) {
        val user = userRepository.findById(userId)
            ?: throw NotFoundException("User", userId)

        user.activate()
        userRepository.save(user)
    }
}
