-- ========================================
-- Orders Context - Tables Creation
-- ========================================
-- Bounded Context: Orders
-- Aggregates: Order
-- Purpose: Order management and lifecycle tracking

-- Orders Table (Aggregate Root)
CREATE TABLE orders.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number VARCHAR(50) NOT NULL UNIQUE,
    user_id UUID NOT NULL, -- Reference to identity.users
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'REFUNDED', 'FAILED')),

    -- Totals
    subtotal NUMERIC(12, 2) NOT NULL CHECK (subtotal >= 0),
    tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    shipping_cost NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Shipping Address (embedded value object)
    shipping_address_line1 VARCHAR(200) NOT NULL,
    shipping_address_line2 VARCHAR(200),
    shipping_city VARCHAR(100) NOT NULL,
    shipping_state VARCHAR(100),
    shipping_postal_code VARCHAR(20) NOT NULL,
    shipping_country VARCHAR(2) NOT NULL, -- ISO 3166-1 alpha-2
    shipping_phone VARCHAR(20),

    -- Billing Address (embedded value object)
    billing_address_line1 VARCHAR(200) NOT NULL,
    billing_address_line2 VARCHAR(200),
    billing_city VARCHAR(100) NOT NULL,
    billing_state VARCHAR(100),
    billing_postal_code VARCHAR(20) NOT NULL,
    billing_country VARCHAR(2) NOT NULL,

    -- Metadata
    notes TEXT,
    ip_address INET,
    user_agent TEXT,

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP,
    shipped_at TIMESTAMP,
    delivered_at TIMESTAMP,
    cancelled_at TIMESTAMP
);

-- Order Items Table (Entity within Order aggregate)
CREATE TABLE orders.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL, -- Reference to catalog.products
    product_sku VARCHAR(50) NOT NULL, -- Snapshot of SKU at time of order
    product_name VARCHAR(150) NOT NULL, -- Snapshot of name at time of order
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    tax_amount NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (tax_amount >= 0),
    total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Order Status History Table (for audit trail)
CREATE TABLE orders.order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders.orders(id) ON DELETE CASCADE,
    from_status VARCHAR(30),
    to_status VARCHAR(30) NOT NULL,
    reason TEXT,
    changed_by UUID, -- Reference to identity.users or system
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Order Discounts Table (applied coupons/promotions)
CREATE TABLE orders.order_discounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders.orders(id) ON DELETE CASCADE,
    discount_code VARCHAR(50),
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('COUPON', 'PROMOTION', 'LOYALTY', 'MANUAL')),
    discount_amount NUMERIC(10, 2) NOT NULL CHECK (discount_amount >= 0),
    description VARCHAR(200),
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_orders_user ON orders.orders(user_id);
CREATE INDEX idx_orders_status ON orders.orders(status);
CREATE INDEX idx_orders_order_number ON orders.orders(order_number);
CREATE INDEX idx_orders_created ON orders.orders(created_at DESC);
CREATE INDEX idx_orders_confirmed ON orders.orders(confirmed_at DESC) WHERE confirmed_at IS NOT NULL;
CREATE INDEX idx_orders_shipped ON orders.orders(shipped_at DESC) WHERE shipped_at IS NOT NULL;

CREATE INDEX idx_order_items_order ON orders.order_items(order_id);
CREATE INDEX idx_order_items_product ON orders.order_items(product_id);

CREATE INDEX idx_order_status_history_order ON orders.order_status_history(order_id);
CREATE INDEX idx_order_status_history_changed ON orders.order_status_history(changed_at DESC);

CREATE INDEX idx_order_discounts_order ON orders.order_discounts(order_id);
CREATE INDEX idx_order_discounts_code ON orders.order_discounts(discount_code) WHERE discount_code IS NOT NULL;

-- Comments for documentation
COMMENT ON TABLE orders.orders IS 'Orders - Aggregate Root for Orders Context';
COMMENT ON TABLE orders.order_items IS 'Order line items - Entity within Order aggregate';
COMMENT ON TABLE orders.order_status_history IS 'Order status change history for audit trail';
COMMENT ON TABLE orders.order_discounts IS 'Discounts applied to orders';

COMMENT ON COLUMN orders.orders.order_number IS 'Human-readable unique order identifier';
COMMENT ON COLUMN orders.order_items.product_sku IS 'Snapshot of product SKU at time of order';
COMMENT ON COLUMN orders.order_items.product_name IS 'Snapshot of product name at time of order';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION orders.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders.orders
    FOR EACH ROW
    EXECUTE FUNCTION orders.update_updated_at_column();

-- Function to track order status changes
CREATE OR REPLACE FUNCTION orders.track_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
        INSERT INTO orders.order_status_history (
            order_id,
            from_status,
            to_status,
            changed_at
        ) VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            CURRENT_TIMESTAMP
        );

        -- Update timestamp fields based on new status
        IF NEW.status = 'CONFIRMED' THEN
            NEW.confirmed_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'SHIPPED' THEN
            NEW.shipped_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'DELIVERED' THEN
            NEW.delivered_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'CANCELLED' THEN
            NEW.cancelled_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track status changes
CREATE TRIGGER track_order_status_change_trigger
    BEFORE UPDATE ON orders.orders
    FOR EACH ROW
    EXECUTE FUNCTION orders.track_order_status_change();

-- Function to generate order number
CREATE OR REPLACE FUNCTION orders.generate_order_number()
RETURNS VARCHAR(50) AS $$
DECLARE
    new_order_number VARCHAR(50);
    year_month VARCHAR(6);
    sequence_num INTEGER;
BEGIN
    -- Format: ORD-YYYYMM-NNNNN (e.g., ORD-202511-00001)
    year_month := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMM');

    -- Get the next sequence number for this month
    SELECT COALESCE(MAX(SUBSTRING(order_number FROM 12)::INTEGER), 0) + 1
    INTO sequence_num
    FROM orders.orders
    WHERE order_number LIKE 'ORD-' || year_month || '-%';

    new_order_number := 'ORD-' || year_month || '-' || LPAD(sequence_num::TEXT, 5, '0');

    RETURN new_order_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate order number
CREATE OR REPLACE FUNCTION orders.set_order_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.order_number IS NULL THEN
        NEW.order_number = orders.generate_order_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_order_number_trigger
    BEFORE INSERT ON orders.orders
    FOR EACH ROW
    EXECUTE FUNCTION orders.set_order_number();
