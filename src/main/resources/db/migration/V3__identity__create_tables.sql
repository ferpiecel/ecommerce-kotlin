-- ========================================
-- Identity & Access Context - Tables Creation
-- ========================================
-- Bounded Context: Identity & Access
-- Aggregates: User, Role
-- Purpose: User management, authentication, and authorization

-- Users Table (Aggregate Root)
CREATE TABLE identity.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    date_of_birth DATE,
    phone_number VARCHAR(20),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION')),
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    registered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_user_username UNIQUE (username),
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

-- Roles Table (Aggregate Root)
CREATE TABLE identity.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) NOT NULL,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE, -- TRUE for built-in roles (ADMIN, USER, etc.)
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_role_name UNIQUE (name)
);

-- Permissions Table (Value Object)
CREATE TABLE identity.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(100) NOT NULL,
    description TEXT,
    resource VARCHAR(50) NOT NULL, -- 'PRODUCT', 'ORDER', 'USER', etc.
    action VARCHAR(50) NOT NULL, -- 'CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST'
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_permission_code UNIQUE (code),
    CONSTRAINT uq_permission_resource_action UNIQUE (resource, action)
);

-- User Roles Association
CREATE TABLE identity.user_roles (
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES identity.roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_by UUID, -- User ID who assigned the role
    expires_at TIMESTAMP, -- Optional: for temporary role assignments

    PRIMARY KEY (user_id, role_id)
);

-- Role Permissions Association
CREATE TABLE identity.role_permissions (
    role_id UUID NOT NULL REFERENCES identity.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES identity.permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (role_id, permission_id)
);

-- Refresh Tokens Table (for JWT refresh token storage)
CREATE TABLE identity.refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    device_info JSONB, -- Browser, OS, IP, etc.
    expires_at TIMESTAMP NOT NULL,
    revoked BOOLEAN DEFAULT FALSE,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
);

-- Password Reset Tokens
CREATE TABLE identity.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_password_reset_token UNIQUE (token_hash)
);

-- Email Verification Tokens
CREATE TABLE identity.email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES identity.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_email_verification_token UNIQUE (token_hash)
);

-- Indexes for performance
CREATE INDEX idx_users_username ON identity.users(username);
CREATE INDEX idx_users_email ON identity.users(email);
CREATE INDEX idx_users_status ON identity.users(status);
CREATE INDEX idx_users_last_login ON identity.users(last_login_at DESC);
CREATE INDEX idx_user_roles_user ON identity.user_roles(user_id);
CREATE INDEX idx_user_roles_role ON identity.user_roles(role_id);
CREATE INDEX idx_role_permissions_role ON identity.role_permissions(role_id);
CREATE INDEX idx_refresh_tokens_user ON identity.refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires ON identity.refresh_tokens(expires_at) WHERE NOT revoked;
CREATE INDEX idx_password_reset_user ON identity.password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_expires ON identity.password_reset_tokens(expires_at) WHERE NOT used;

-- Comments for documentation
COMMENT ON TABLE identity.users IS 'User accounts - Aggregate Root for Identity Context';
COMMENT ON TABLE identity.roles IS 'User roles - Aggregate Root';
COMMENT ON TABLE identity.permissions IS 'System permissions - Value Object';
COMMENT ON TABLE identity.user_roles IS 'User-Role associations with optional expiration';
COMMENT ON TABLE identity.refresh_tokens IS 'JWT refresh tokens for session management';
COMMENT ON TABLE identity.password_reset_tokens IS 'Password reset tokens';
COMMENT ON TABLE identity.email_verification_tokens IS 'Email verification tokens';

COMMENT ON COLUMN identity.users.password_hash IS 'Bcrypt hashed password';
COMMENT ON COLUMN identity.users.failed_login_attempts IS 'Counter for account locking after failed attempts';
COMMENT ON COLUMN identity.users.locked_until IS 'Account locked until this timestamp';
COMMENT ON COLUMN identity.permissions.code IS 'Permission code format: RESOURCE:ACTION (e.g., PRODUCT:CREATE)';

-- Triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON identity.users
    FOR EACH ROW
    EXECUTE FUNCTION catalog.update_updated_at_column();

CREATE TRIGGER update_roles_updated_at
    BEFORE UPDATE ON identity.roles
    FOR EACH ROW
    EXECUTE FUNCTION catalog.update_updated_at_column();

-- Function to clean expired tokens
CREATE OR REPLACE FUNCTION identity.clean_expired_tokens()
RETURNS void AS $$
BEGIN
    -- Delete expired refresh tokens
    DELETE FROM identity.refresh_tokens
    WHERE expires_at < CURRENT_TIMESTAMP AND revoked = FALSE;

    -- Delete old used password reset tokens (older than 7 days)
    DELETE FROM identity.password_reset_tokens
    WHERE used = TRUE AND used_at < CURRENT_TIMESTAMP - INTERVAL '7 days';

    -- Delete expired unused password reset tokens
    DELETE FROM identity.password_reset_tokens
    WHERE used = FALSE AND expires_at < CURRENT_TIMESTAMP;

    -- Delete old verified email tokens (older than 7 days)
    DELETE FROM identity.email_verification_tokens
    WHERE verified = TRUE AND verified_at < CURRENT_TIMESTAMP - INTERVAL '7 days';

    -- Delete expired unverified email tokens
    DELETE FROM identity.email_verification_tokens
    WHERE verified = FALSE AND expires_at < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Insert default roles
INSERT INTO identity.roles (name, description, is_system_role) VALUES
    ('ADMIN', 'System administrator with full access', TRUE),
    ('USER', 'Regular user with basic access', TRUE),
    ('CUSTOMER', 'Customer with shopping capabilities', TRUE),
    ('VENDOR', 'Vendor/seller with product management access', TRUE);

-- Insert default permissions
INSERT INTO identity.permissions (code, description, resource, action) VALUES
    -- Product permissions
    ('PRODUCT:CREATE', 'Create products', 'PRODUCT', 'CREATE'),
    ('PRODUCT:READ', 'View products', 'PRODUCT', 'READ'),
    ('PRODUCT:UPDATE', 'Update products', 'PRODUCT', 'UPDATE'),
    ('PRODUCT:DELETE', 'Delete products', 'PRODUCT', 'DELETE'),
    ('PRODUCT:LIST', 'List all products', 'PRODUCT', 'LIST'),

    -- Order permissions
    ('ORDER:CREATE', 'Create orders', 'ORDER', 'CREATE'),
    ('ORDER:READ', 'View orders', 'ORDER', 'READ'),
    ('ORDER:UPDATE', 'Update orders', 'ORDER', 'UPDATE'),
    ('ORDER:CANCEL', 'Cancel orders', 'ORDER', 'CANCEL'),
    ('ORDER:LIST', 'List all orders', 'ORDER', 'LIST'),

    -- User permissions
    ('USER:CREATE', 'Create users', 'USER', 'CREATE'),
    ('USER:READ', 'View users', 'USER', 'READ'),
    ('USER:UPDATE', 'Update users', 'USER', 'UPDATE'),
    ('USER:DELETE', 'Delete users', 'USER', 'DELETE'),
    ('USER:LIST', 'List all users', 'USER', 'LIST');

-- Assign permissions to ADMIN role (all permissions)
INSERT INTO identity.role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM identity.roles WHERE name = 'ADMIN'),
    id
FROM identity.permissions;

-- Assign basic permissions to USER role
INSERT INTO identity.role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM identity.roles WHERE name = 'USER'),
    id
FROM identity.permissions
WHERE code IN ('PRODUCT:READ', 'PRODUCT:LIST');

-- Assign customer permissions to CUSTOMER role
INSERT INTO identity.role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM identity.roles WHERE name = 'CUSTOMER'),
    id
FROM identity.permissions
WHERE code IN (
    'PRODUCT:READ', 'PRODUCT:LIST',
    'ORDER:CREATE', 'ORDER:READ', 'ORDER:CANCEL'
);

-- Assign vendor permissions to VENDOR role
INSERT INTO identity.role_permissions (role_id, permission_id)
SELECT
    (SELECT id FROM identity.roles WHERE name = 'VENDOR'),
    id
FROM identity.permissions
WHERE code LIKE 'PRODUCT:%' OR code IN ('ORDER:READ', 'ORDER:LIST');
