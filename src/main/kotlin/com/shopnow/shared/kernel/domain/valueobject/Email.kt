package com.shopnow.shared.kernel.domain.valueobject

/**
 * Email Value Object
 *
 * Represents a valid email address.
 * Immutable and self-validating.
 */
@JvmInline
value class Email(val value: String) {
    init {
        require(isValid(value)) { "Invalid email format: $value" }
    }

    companion object {
        private val EMAIL_REGEX = "^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$".toRegex()

        fun isValid(email: String): Boolean {
            return email.isNotBlank() && EMAIL_REGEX.matches(email)
        }

        fun of(value: String): Email = Email(value.lowercase().trim())
    }

    fun domain(): String = value.substringAfter("@")
    fun localPart(): String = value.substringBefore("@")

    override fun toString(): String = value
}
