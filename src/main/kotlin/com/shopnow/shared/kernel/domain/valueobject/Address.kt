package com.shopnow.shared.kernel.domain.valueobject

/**
 * Address Value Object
 *
 * Represents a physical address.
 * Immutable and self-validating.
 */
data class Address(
    val line1: String,
    val line2: String? = null,
    val city: String,
    val state: String? = null,
    val postalCode: String,
    val country: CountryCode
) {
    init {
        require(line1.isNotBlank()) { "Address line1 cannot be blank" }
        require(city.isNotBlank()) { "City cannot be blank" }
        require(postalCode.isNotBlank()) { "Postal code cannot be blank" }
    }

    companion object {
        fun of(
            line1: String,
            line2: String? = null,
            city: String,
            state: String? = null,
            postalCode: String,
            countryCode: String
        ): Address {
            return Address(
                line1 = line1.trim(),
                line2 = line2?.trim(),
                city = city.trim(),
                state = state?.trim(),
                postalCode = postalCode.trim(),
                country = CountryCode(countryCode)
            )
        }
    }

    fun fullAddress(): String {
        val parts = listOfNotNull(
            line1,
            line2,
            city,
            state,
            postalCode,
            country.value
        )
        return parts.joinToString(", ")
    }

    override fun toString(): String = fullAddress()
}

/**
 * CountryCode Value Object
 * ISO 3166-1 alpha-2 country code
 */
@JvmInline
value class CountryCode(val value: String) {
    init {
        require(value.length == 2 && value.all { it.isUpperCase() }) {
            "Country code must be ISO 3166-1 alpha-2 format (e.g., US, MX, CA)"
        }
    }

    companion object {
        fun of(code: String): CountryCode = CountryCode(code.uppercase().trim())
    }

    override fun toString(): String = value
}
