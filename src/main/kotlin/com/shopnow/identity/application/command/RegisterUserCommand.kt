package com.shopnow.identity.application.command

import java.time.LocalDate

/**
 * Register User Command
 *
 * Command for registering a new user.
 */
data class RegisterUserCommand(
    val username: String,
    val email: String,
    val password: String,
    val firstName: String? = null,
    val lastName: String? = null,
    val dateOfBirth: LocalDate? = null,
    val phoneNumber: String? = null
)
