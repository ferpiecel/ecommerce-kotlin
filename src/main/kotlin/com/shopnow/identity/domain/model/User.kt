package com.shopnow.identity.domain.model

import com.shopnow.shared.kernel.domain.AggregateRoot
import com.shopnow.shared.kernel.domain.BaseDomainEvent
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.*

/**
 * User Aggregate Root
 *
 * Represents a user in the identity and access context.
 * Manages user profile, authentication, and account status.
 */
class User private constructor(
    override val id: UUID,
    var username: String,
    var email: Email,
    var password: Password,
    var firstName: String?,
    var lastName: String?,
    var dateOfBirth: LocalDate?,
    var phoneNumber: String?,
    var status: UserStatus,
    var emailVerified: Boolean = false,
    var phoneVerified: Boolean = false,
    var registeredAt: LocalDateTime,
    var lastLoginAt: LocalDateTime? = null,
    var failedLoginAttempts: Int = 0,
    var lockedUntil: LocalDateTime? = null
) : AggregateRoot<UUID>() {

    companion object {
        private const val MAX_FAILED_ATTEMPTS = 5
        private const val LOCK_DURATION_MINUTES = 30L

        /**
         * Register a new user.
         */
        fun register(
            username: String,
            email: Email,
            password: Password,
            firstName: String? = null,
            lastName: String? = null,
            dateOfBirth: LocalDate? = null,
            phoneNumber: String? = null
        ): User {
            require(username.isNotBlank()) { "Username cannot be blank" }
            require(username.length >= 3) { "Username must be at least 3 characters long" }
            require(username.length <= 50) { "Username must not exceed 50 characters" }
            require(username.matches(Regex("^[a-zA-Z0-9_-]+$"))) {
                "Username can only contain letters, numbers, underscores, and hyphens"
            }

            val user = User(
                id = UUID.randomUUID(),
                username = username,
                email = email,
                password = password,
                firstName = firstName,
                lastName = lastName,
                dateOfBirth = dateOfBirth,
                phoneNumber = phoneNumber,
                status = UserStatus.PENDING_VERIFICATION,
                registeredAt = LocalDateTime.now()
            )

            user.registerEvent(UserRegisteredEvent(user.id, username, email.value))
            return user
        }
    }

    /**
     * Activate the user account.
     */
    fun activate() {
        if (status != UserStatus.ACTIVE) {
            status = UserStatus.ACTIVE
            registerEvent(UserActivatedEvent(id, username))
        }
    }

    /**
     * Deactivate the user account.
     */
    fun deactivate() {
        if (status == UserStatus.ACTIVE) {
            status = UserStatus.INACTIVE
            registerEvent(UserDeactivatedEvent(id, username))
        }
    }

    /**
     * Suspend the user account (admin action).
     */
    fun suspend() {
        if (status != UserStatus.SUSPENDED) {
            status = UserStatus.SUSPENDED
            registerEvent(UserSuspendedEvent(id, username))
        }
    }

    /**
     * Update user profile information.
     */
    fun updateProfile(
        firstName: String?,
        lastName: String?,
        dateOfBirth: LocalDate?,
        phoneNumber: String?
    ) {
        this.firstName = firstName
        this.lastName = lastName
        this.dateOfBirth = dateOfBirth
        this.phoneNumber = phoneNumber
        registerEvent(ProfileUpdatedEvent(id, username))
    }

    /**
     * Change user password.
     */
    fun changePassword(oldPassword: String, newPassword: Password) {
        require(password.matches(oldPassword)) { "Current password is incorrect" }
        password = newPassword
        registerEvent(PasswordChangedEvent(id, username))
    }

    /**
     * Verify user email.
     */
    fun verifyEmail() {
        if (!emailVerified) {
            emailVerified = true
            if (status == UserStatus.PENDING_VERIFICATION) {
                status = UserStatus.ACTIVE
            }
            registerEvent(EmailVerifiedEvent(id, email.value))
        }
    }

    /**
     * Verify user phone number.
     */
    fun verifyPhone() {
        if (!phoneVerified) {
            phoneVerified = true
            registerEvent(PhoneVerifiedEvent(id, phoneNumber ?: ""))
        }
    }

    /**
     * Record successful login.
     */
    fun recordSuccessfulLogin() {
        lastLoginAt = LocalDateTime.now()
        failedLoginAttempts = 0
        lockedUntil = null
    }

    /**
     * Record failed login attempt.
     */
    fun recordFailedLogin() {
        failedLoginAttempts++
        if (failedLoginAttempts >= MAX_FAILED_ATTEMPTS) {
            lockedUntil = LocalDateTime.now().plusMinutes(LOCK_DURATION_MINUTES)
            registerEvent(UserLockedEvent(id, username, lockedUntil!!))
        }
    }

    /**
     * Check if account is locked.
     */
    fun isLocked(): Boolean {
        return lockedUntil?.let { it.isAfter(LocalDateTime.now()) } ?: false
    }

    /**
     * Check if user can login.
     */
    fun canLogin(): Boolean {
        return status == UserStatus.ACTIVE && !isLocked()
    }

    /**
     * Get full name.
     */
    fun getFullName(): String {
        return when {
            firstName != null && lastName != null -> "$firstName $lastName"
            firstName != null -> firstName!!
            lastName != null -> lastName!!
            else -> username
        }
    }
}

// Domain Events
class UserRegisteredEvent(
    aggregateId: UUID,
    val username: String,
    val email: String
) : BaseDomainEvent(aggregateId, "UserRegistered")

class UserActivatedEvent(
    aggregateId: UUID,
    val username: String
) : BaseDomainEvent(aggregateId, "UserActivated")

class UserDeactivatedEvent(
    aggregateId: UUID,
    val username: String
) : BaseDomainEvent(aggregateId, "UserDeactivated")

class UserSuspendedEvent(
    aggregateId: UUID,
    val username: String
) : BaseDomainEvent(aggregateId, "UserSuspended")

class ProfileUpdatedEvent(
    aggregateId: UUID,
    val username: String
) : BaseDomainEvent(aggregateId, "ProfileUpdated")

class PasswordChangedEvent(
    aggregateId: UUID,
    val username: String
) : BaseDomainEvent(aggregateId, "PasswordChanged")

class EmailVerifiedEvent(
    aggregateId: UUID,
    val email: String
) : BaseDomainEvent(aggregateId, "EmailVerified")

class PhoneVerifiedEvent(
    aggregateId: UUID,
    val phoneNumber: String
) : BaseDomainEvent(aggregateId, "PhoneVerified")

class UserLockedEvent(
    aggregateId: UUID,
    val username: String,
    val lockedUntil: LocalDateTime
) : BaseDomainEvent(aggregateId, "UserLocked")
