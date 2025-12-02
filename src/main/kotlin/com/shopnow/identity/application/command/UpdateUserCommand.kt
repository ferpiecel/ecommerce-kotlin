package com.shopnow.identity.application.command

import java.time.LocalDate

/**
 * Update User Command
 *
 * Command for updating user profile information.
 */
data class UpdateUserCommand(
    val firstName: String? = null,
    val lastName: String? = null,
    val dateOfBirth: LocalDate? = null,
    val phoneNumber: String? = null
)
