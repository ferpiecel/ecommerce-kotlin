package com.shopnow.identity.application.usecase

import com.shopnow.identity.application.command.RegisterUserCommand
import com.shopnow.identity.domain.model.Email
import com.shopnow.identity.domain.model.Password
import com.shopnow.identity.domain.model.User
import com.shopnow.identity.domain.repository.UserRepository
import com.shopnow.shared.kernel.domain.BusinessRuleViolationException
import org.springframework.stereotype.Service
import java.util.*

/**
 * Register User Use Case
 *
 * Application service that orchestrates user registration.
 */
@Service
class RegisterUserUseCase(
    private val userRepository: UserRepository
) {
    suspend fun execute(command: RegisterUserCommand): UUID {
        // Business rule: Username must be unique
        if (userRepository.existsByUsername(command.username)) {
            throw BusinessRuleViolationException(
                "UniqueUsername",
                "User with username '${command.username}' already exists"
            )
        }

        // Business rule: Email must be unique
        if (userRepository.existsByEmail(command.email)) {
            throw BusinessRuleViolationException(
                "UniqueEmail",
                "User with email '${command.email}' already exists"
            )
        }

        val email = Email.of(command.email)
        val password = Password.fromPlainText(command.password)

        val user = User.register(
            username = command.username,
            email = email,
            password = password,
            firstName = command.firstName,
            lastName = command.lastName,
            dateOfBirth = command.dateOfBirth,
            phoneNumber = command.phoneNumber
        )

        val savedUser = userRepository.save(user)

        // Domain events will be published by infrastructure layer
        return savedUser.id
    }
}
