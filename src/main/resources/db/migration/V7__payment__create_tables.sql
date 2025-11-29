-- ========================================
-- Payment Context - Tables Creation
-- ========================================
-- Bounded Context: Payment
-- Aggregates: Payment, PaymentMethod
-- Purpose: Payment processing and transaction management

-- Payment Methods Table (Aggregate Root)
CREATE TABLE payment.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Reference to identity.users
    type VARCHAR(30) NOT NULL CHECK (type IN ('CREDIT_CARD', 'DEBIT_CARD', 'PAYPAL', 'BANK_TRANSFER', 'CASH_ON_DELIVERY')),

    -- Card details (encrypted in production)
    card_last_four VARCHAR(4),
    card_brand VARCHAR(20), -- VISA, MASTERCARD, AMEX, etc.
    card_expiry_month INTEGER CHECK (card_expiry_month >= 1 AND card_expiry_month <= 12),
    card_expiry_year INTEGER,
    cardholder_name VARCHAR(100),

    -- PayPal
    paypal_email VARCHAR(100),

    -- Bank transfer
    bank_account_last_four VARCHAR(4),
    bank_name VARCHAR(100),

    -- Billing address
    billing_address_line1 VARCHAR(200),
    billing_address_line2 VARCHAR(200),
    billing_city VARCHAR(100),
    billing_state VARCHAR(100),
    billing_postal_code VARCHAR(20),
    billing_country VARCHAR(2),

    -- Metadata
    is_default BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    nickname VARCHAR(50),

    -- Payment gateway reference
    gateway_customer_id VARCHAR(100), -- Stripe, PayPal, etc.
    gateway_payment_method_id VARCHAR(100),

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Partial unique index for default payment method per user
CREATE UNIQUE INDEX uq_default_payment_method_user ON payment.payment_methods (user_id)
    WHERE is_default = TRUE;

-- Payments Table (Aggregate Root)
CREATE TABLE payment.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_number VARCHAR(50) NOT NULL UNIQUE,
    order_id UUID NOT NULL, -- Reference to orders.orders
    user_id UUID NOT NULL, -- Reference to identity.users
    payment_method_id UUID REFERENCES payment.payment_methods(id),

    -- Payment details
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'AUTHORIZED', 'CAPTURED', 'COMPLETED', 'FAILED', 'CANCELLED', 'REFUNDED', 'PARTIALLY_REFUNDED')),

    -- Payment gateway details
    gateway_provider VARCHAR(30) NOT NULL, -- STRIPE, PAYPAL, ADYEN, etc.
    gateway_transaction_id VARCHAR(100),
    gateway_status VARCHAR(50),
    gateway_response JSONB,

    -- Fraud detection
    risk_score NUMERIC(5, 2) CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_level VARCHAR(20) CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    is_flagged BOOLEAN DEFAULT FALSE,

    -- Metadata
    description TEXT,
    ip_address INET,
    user_agent TEXT,

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    authorized_at TIMESTAMP,
    captured_at TIMESTAMP,
    completed_at TIMESTAMP,
    failed_at TIMESTAMP,
    cancelled_at TIMESTAMP
);

-- Payment Transactions Table (for transaction history and idempotency)
CREATE TABLE payment.payment_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payment.payments(id) ON DELETE CASCADE,
    transaction_type VARCHAR(30) NOT NULL
        CHECK (transaction_type IN ('AUTHORIZE', 'CAPTURE', 'VOID', 'REFUND', 'PARTIAL_REFUND')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    status VARCHAR(30) NOT NULL CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED')),

    -- Gateway details
    gateway_transaction_id VARCHAR(100),
    gateway_response JSONB,
    error_code VARCHAR(50),
    error_message TEXT,

    -- Idempotency
    idempotency_key VARCHAR(100) UNIQUE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP
);

-- Refunds Table
CREATE TABLE payment.refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payment.payments(id),
    refund_number VARCHAR(50) NOT NULL UNIQUE,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    reason VARCHAR(30) CHECK (reason IN ('REQUESTED_BY_CUSTOMER', 'FRAUDULENT', 'DUPLICATE', 'PRODUCT_DEFECTIVE', 'OTHER')),
    reason_details TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')),

    -- Gateway details
    gateway_refund_id VARCHAR(100),
    gateway_response JSONB,

    -- Metadata
    refunded_by UUID, -- Reference to identity.users
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    completed_at TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_payment_methods_user ON payment.payment_methods(user_id);
CREATE INDEX idx_payment_methods_type ON payment.payment_methods(type);
CREATE INDEX idx_payment_methods_gateway_customer ON payment.payment_methods(gateway_customer_id) WHERE gateway_customer_id IS NOT NULL;

CREATE INDEX idx_payments_order ON payment.payments(order_id);
CREATE INDEX idx_payments_user ON payment.payments(user_id);
CREATE INDEX idx_payments_status ON payment.payments(status);
CREATE INDEX idx_payments_payment_number ON payment.payments(payment_number);
CREATE INDEX idx_payments_created ON payment.payments(created_at DESC);
CREATE INDEX idx_payments_flagged ON payment.payments(is_flagged) WHERE is_flagged = TRUE;
CREATE INDEX idx_payments_gateway_transaction ON payment.payments(gateway_transaction_id) WHERE gateway_transaction_id IS NOT NULL;

CREATE INDEX idx_payment_transactions_payment ON payment.payment_transactions(payment_id);
CREATE INDEX idx_payment_transactions_idempotency ON payment.payment_transactions(idempotency_key) WHERE idempotency_key IS NOT NULL;
CREATE INDEX idx_payment_transactions_created ON payment.payment_transactions(created_at DESC);

CREATE INDEX idx_refunds_payment ON payment.refunds(payment_id);
CREATE INDEX idx_refunds_refund_number ON payment.refunds(refund_number);
CREATE INDEX idx_refunds_status ON payment.refunds(status);

-- Comments for documentation
COMMENT ON TABLE payment.payment_methods IS 'Saved payment methods - Aggregate Root';
COMMENT ON TABLE payment.payments IS 'Payment transactions - Aggregate Root for Payment Context';
COMMENT ON TABLE payment.payment_transactions IS 'Payment transaction history and state changes';
COMMENT ON TABLE payment.refunds IS 'Payment refunds and reversals';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION payment.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_payment_methods_updated_at
    BEFORE UPDATE ON payment.payment_methods
    FOR EACH ROW
    EXECUTE FUNCTION payment.update_updated_at_column();

CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON payment.payments
    FOR EACH ROW
    EXECUTE FUNCTION payment.update_updated_at_column();

-- Function to track payment status changes
CREATE OR REPLACE FUNCTION payment.track_payment_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
        -- Update timestamp fields based on new status
        IF NEW.status = 'AUTHORIZED' THEN
            NEW.authorized_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'CAPTURED' THEN
            NEW.captured_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'COMPLETED' THEN
            NEW.completed_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'FAILED' THEN
            NEW.failed_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'CANCELLED' THEN
            NEW.cancelled_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track payment status changes
CREATE TRIGGER track_payment_status_change_trigger
    BEFORE UPDATE ON payment.payments
    FOR EACH ROW
    EXECUTE FUNCTION payment.track_payment_status_change();

-- Function to generate payment number
CREATE OR REPLACE FUNCTION payment.generate_payment_number()
RETURNS VARCHAR(50) AS $$
DECLARE
    new_payment_number VARCHAR(50);
    year_month VARCHAR(6);
    sequence_num INTEGER;
BEGIN
    -- Format: PAY-YYYYMM-NNNNN
    year_month := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMM');

    SELECT COALESCE(MAX(SUBSTRING(payment_number FROM 12)::INTEGER), 0) + 1
    INTO sequence_num
    FROM payment.payments
    WHERE payment_number LIKE 'PAY-' || year_month || '-%';

    new_payment_number := 'PAY-' || year_month || '-' || LPAD(sequence_num::TEXT, 5, '0');

    RETURN new_payment_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate payment number
CREATE OR REPLACE FUNCTION payment.set_payment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payment_number IS NULL THEN
        NEW.payment_number = payment.generate_payment_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_payment_number_trigger
    BEFORE INSERT ON payment.payments
    FOR EACH ROW
    EXECUTE FUNCTION payment.set_payment_number();

-- Function to generate refund number
CREATE OR REPLACE FUNCTION payment.generate_refund_number()
RETURNS VARCHAR(50) AS $$
DECLARE
    new_refund_number VARCHAR(50);
    year_month VARCHAR(6);
    sequence_num INTEGER;
BEGIN
    -- Format: REF-YYYYMM-NNNNN
    year_month := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMM');

    SELECT COALESCE(MAX(SUBSTRING(refund_number FROM 12)::INTEGER), 0) + 1
    INTO sequence_num
    FROM payment.refunds
    WHERE refund_number LIKE 'REF-' || year_month || '-%';

    new_refund_number := 'REF-' || year_month || '-' || LPAD(sequence_num::TEXT, 5, '0');

    RETURN new_refund_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate refund number
CREATE OR REPLACE FUNCTION payment.set_refund_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.refund_number IS NULL THEN
        NEW.refund_number = payment.generate_refund_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_refund_number_trigger
    BEFORE INSERT ON payment.refunds
    FOR EACH ROW
    EXECUTE FUNCTION payment.set_refund_number();
