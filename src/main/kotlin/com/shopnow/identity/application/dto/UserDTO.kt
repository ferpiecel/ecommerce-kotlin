package com.shopnow.identity.application.dto

import com.shopnow.identity.domain.model.User
import com.shopnow.identity.domain.model.UserStatus
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.*

/**
 * User Data Transfer Object
 *
 * Used for API responses. Does not expose sensitive information like password.
 */
data class UserDTO(
    val id: UUID,
    val username: String,
    val email: String,
    val firstName: String?,
    val lastName: String?,
    val fullName: String,
    val dateOfBirth: LocalDate?,
    val phoneNumber: String?,
    val status: UserStatus,
    val emailVerified: Boolean,
    val phoneVerified: Boolean,
    val registeredAt: LocalDateTime,
    val lastLoginAt: LocalDateTime?
) {
    companion object {
        fun fromDomain(user: User): UserDTO {
            return UserDTO(
                id = user.id,
                username = user.username,
                email = user.email.value,
                firstName = user.firstName,
                lastName = user.lastName,
                fullName = user.getFullName(),
                dateOfBirth = user.dateOfBirth,
                phoneNumber = user.phoneNumber,
                status = user.status,
                emailVerified = user.emailVerified,
                phoneVerified = user.phoneVerified,
                registeredAt = user.registeredAt,
                lastLoginAt = user.lastLoginAt
            )
        }
    }
}
