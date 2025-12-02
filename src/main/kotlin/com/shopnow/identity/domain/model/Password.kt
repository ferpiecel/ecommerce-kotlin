package com.shopnow.identity.domain.model

import com.shopnow.shared.kernel.domain.ValueObject
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder

/**
 * Password Value Object
 *
 * Represents a hashed password with validation.
 * Uses BCrypt for hashing.
 */
data class Password private constructor(val hash: String) : ValueObject {

    companion object {
        private val encoder by lazy { BCryptPasswordEncoder() }
        private const val MIN_LENGTH = 8
        private const val MAX_LENGTH = 100

        /**
         * Create a Password from a plain text password.
         * Validates strength and hashes the password.
         */
        fun fromPlainText(plainPassword: String): Password {
            require(plainPassword.length >= MIN_LENGTH) {
                "Password must be at least $MIN_LENGTH characters long"
            }
            require(plainPassword.length <= MAX_LENGTH) {
                "Password must not exceed $MAX_LENGTH characters"
            }
            require(hasUpperCase(plainPassword)) {
                "Password must contain at least one uppercase letter"
            }
            require(hasLowerCase(plainPassword)) {
                "Password must contain at least one lowercase letter"
            }
            require(hasDigit(plainPassword)) {
                "Password must contain at least one digit"
            }

            val hash = encoder.encode(plainPassword)
            return Password(hash)
        }

        /**
         * Create a Password from an already hashed password.
         * Used when loading from database.
         */
        fun fromHash(hash: String): Password {
            require(hash.isNotBlank()) { "Password hash cannot be blank" }
            return Password(hash)
        }

        private fun hasUpperCase(password: String): Boolean = password.any { it.isUpperCase() }
        private fun hasLowerCase(password: String): Boolean = password.any { it.isLowerCase() }
        private fun hasDigit(password: String): Boolean = password.any { it.isDigit() }
    }

    /**
     * Verify if a plain text password matches this hashed password.
     */
    fun matches(plainPassword: String): Boolean {
        return encoder.matches(plainPassword, hash)
    }

    override fun toString(): String = "[PROTECTED]"
}
