package com.shopnow.identity.domain.model

import com.shopnow.shared.kernel.domain.ValueObject

/**
 * Email Value Object
 *
 * Represents a validated email address.
 * Immutable and validates format on creation.
 */
data class Email(val value: String) : ValueObject {
    
    init {
        require(value.isNotBlank()) { "Email cannot be blank" }
        require(isValidFormat(value)) { "Invalid email format: $value" }
    }

    companion object {
        private val EMAIL_REGEX = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\$".toRegex()

        fun isValidFormat(email: String): Boolean {
            return EMAIL_REGEX.matches(email)
        }

        fun of(value: String): Email = Email(value.lowercase().trim())
    }

    override fun toString(): String = value
}
