package com.shopnow.shared.kernel.domain.valueobject

import java.math.BigDecimal
import java.math.RoundingMode
import java.util.Currency

/**
 * Money Value Object
 *
 * Represents a monetary amount with currency.
 * Immutable and self-validating.
 */
data class Money(
    val amount: BigDecimal,
    val currency: Currency
) {
    init {
        require(amount.scale() <= currency.defaultFractionDigits) {
            "Amount scale cannot exceed ${currency.defaultFractionDigits} for currency ${currency.currencyCode}"
        }
    }

    companion object {
        fun of(amount: Double, currencyCode: String): Money {
            val currency = Currency.getInstance(currencyCode)
            val scaledAmount = BigDecimal.valueOf(amount).setScale(currency.defaultFractionDigits, RoundingMode.HALF_UP)
            return Money(scaledAmount, currency)
        }

        fun of(amount: BigDecimal, currencyCode: String): Money {
            val currency = Currency.getInstance(currencyCode)
            val scaledAmount = amount.setScale(currency.defaultFractionDigits, RoundingMode.HALF_UP)
            return Money(scaledAmount, currency)
        }

        fun zero(currencyCode: String): Money {
            val currency = Currency.getInstance(currencyCode)
            return Money(BigDecimal.ZERO.setScale(currency.defaultFractionDigits), currency)
        }

        fun usd(amount: Double): Money = of(amount, "USD")
        fun usd(amount: BigDecimal): Money = of(amount, "USD")
    }

    fun add(other: Money): Money {
        requireSameCurrency(other)
        return Money(amount.add(other.amount), currency)
    }

    fun subtract(other: Money): Money {
        requireSameCurrency(other)
        return Money(amount.subtract(other.amount), currency)
    }

    fun multiply(multiplier: BigDecimal): Money {
        return Money(
            amount.multiply(multiplier).setScale(currency.defaultFractionDigits, RoundingMode.HALF_UP),
            currency
        )
    }

    fun multiply(multiplier: Int): Money {
        return multiply(BigDecimal.valueOf(multiplier.toLong()))
    }

    fun divide(divisor: BigDecimal): Money {
        return Money(
            amount.divide(divisor, currency.defaultFractionDigits, RoundingMode.HALF_UP),
            currency
        )
    }

    fun isPositive(): Boolean = amount > BigDecimal.ZERO
    fun isNegative(): Boolean = amount < BigDecimal.ZERO
    fun isZero(): Boolean = amount.compareTo(BigDecimal.ZERO) == 0

    fun isGreaterThan(other: Money): Boolean {
        requireSameCurrency(other)
        return amount > other.amount
    }

    fun isLessThan(other: Money): Boolean {
        requireSameCurrency(other)
        return amount < other.amount
    }

    private fun requireSameCurrency(other: Money) {
        require(currency == other.currency) {
            "Cannot perform operation on different currencies: ${currency.currencyCode} and ${other.currency.currencyCode}"
        }
    }

    override fun toString(): String = "${currency.symbol}${amount}"

    fun toCurrencyString(): String = "${currency.currencyCode} ${amount}"
}
