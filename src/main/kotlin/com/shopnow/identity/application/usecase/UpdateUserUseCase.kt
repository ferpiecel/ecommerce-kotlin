package com.shopnow.identity.application.usecase

import com.shopnow.identity.application.command.UpdateUserCommand
import com.shopnow.identity.domain.repository.UserRepository
import com.shopnow.shared.kernel.domain.NotFoundException
import org.springframework.stereotype.Service
import java.util.*

/**
 * Update User Use Case
 *
 * Updates user profile information.
 */
@Service
class UpdateUserUseCase(
    private val userRepository: UserRepository
) {
    suspend fun execute(userId: UUID, command: UpdateUserCommand) {
        val user = userRepository.findById(userId)
            ?: throw NotFoundException("User", userId)

        user.updateProfile(
            firstName = command.firstName,
            lastName = command.lastName,
            dateOfBirth = command.dateOfBirth,
            phoneNumber = command.phoneNumber
        )

        userRepository.save(user)
    }
}
