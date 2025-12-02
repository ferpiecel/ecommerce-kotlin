package com.shopnow.identity.domain.model

/**
 * User Status Enum
 *
 * Represents the different states a user account can be in.
 */
enum class UserStatus {
    /**
     * User account is active and can perform all operations
     */
    ACTIVE,

    /**
     * User account is inactive (e.g., user deactivated their own account)
     */
    INACTIVE,

    /**
     * User account is suspended by admin (e.g., policy violation)
     */
    SUSPENDED,

    /**
     * User has registered but hasn't verified their email yet
     */
    PENDING_VERIFICATION
}
