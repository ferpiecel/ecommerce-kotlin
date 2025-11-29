-- ========================================
-- Shipping Context - Tables Creation
-- ========================================
-- Bounded Context: Shipping
-- Aggregates: Shipment
-- Purpose: Shipping methods, tracking, and delivery management

-- Shipping Methods Table
CREATE TABLE shipping.shipping_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    carrier VARCHAR(50) NOT NULL, -- USPS, FedEx, UPS, DHL, etc.
    estimated_days_min INTEGER CHECK (estimated_days_min >= 0),
    estimated_days_max INTEGER CHECK (estimated_days_max >= estimated_days_min),
    base_cost NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (base_cost >= 0),
    cost_per_kg NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (cost_per_kg >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    supports_tracking BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Shipments Table (Aggregate Root)
CREATE TABLE shipping.shipments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_number VARCHAR(50) NOT NULL UNIQUE,
    order_id UUID NOT NULL, -- Reference to orders.orders
    shipping_method_id UUID NOT NULL REFERENCES shipping.shipping_methods(id),

    -- Shipping details
    carrier VARCHAR(50) NOT NULL,
    service_type VARCHAR(50),
    tracking_number VARCHAR(100),
    tracking_url VARCHAR(500),

    status VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'LABEL_CREATED', 'PICKED_UP', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED', 'RETURNED')),

    -- Package details
    weight_kg NUMERIC(8, 2) CHECK (weight_kg > 0),
    length_cm NUMERIC(8, 2),
    width_cm NUMERIC(8, 2),
    height_cm NUMERIC(8, 2),
    package_count INTEGER DEFAULT 1 CHECK (package_count > 0),

    -- Shipping address (denormalized from order)
    recipient_name VARCHAR(100) NOT NULL,
    address_line1 VARCHAR(200) NOT NULL,
    address_line2 VARCHAR(200),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    postal_code VARCHAR(20) NOT NULL,
    country VARCHAR(2) NOT NULL,
    phone VARCHAR(20),

    -- Costs
    shipping_cost NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (shipping_cost >= 0),
    insurance_cost NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (insurance_cost >= 0),
    total_cost NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (total_cost >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Carrier integration
    carrier_shipment_id VARCHAR(100),
    label_url VARCHAR(500),
    carrier_response JSONB,

    -- Metadata
    notes TEXT,
    special_instructions TEXT,

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    label_created_at TIMESTAMP,
    picked_up_at TIMESTAMP,
    estimated_delivery_at TIMESTAMP,
    delivered_at TIMESTAMP,
    failed_at TIMESTAMP
);

-- Shipment Tracking Events Table
CREATE TABLE shipping.shipment_tracking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL REFERENCES shipping.shipments(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    status VARCHAR(30) NOT NULL,
    location VARCHAR(200),
    description TEXT,
    occurred_at TIMESTAMP NOT NULL,
    carrier_event_code VARCHAR(50),
    carrier_event_data JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Delivery Attempts Table
CREATE TABLE shipping.delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL REFERENCES shipping.shipments(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL CHECK (attempt_number > 0),
    status VARCHAR(30) NOT NULL CHECK (status IN ('ATTEMPTED', 'DELIVERED', 'FAILED')),
    failure_reason VARCHAR(100),
    failure_details TEXT,
    location VARCHAR(200),
    attempted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    delivered_to VARCHAR(100),
    signature_url VARCHAR(500),
    proof_of_delivery_url VARCHAR(500)
);

-- Shipping Rates Cache Table (for performance)
CREATE TABLE shipping.shipping_rates_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_postal_code VARCHAR(20) NOT NULL,
    from_country VARCHAR(2) NOT NULL,
    to_postal_code VARCHAR(20) NOT NULL,
    to_country VARCHAR(2) NOT NULL,
    weight_kg NUMERIC(8, 2) NOT NULL,
    shipping_method_id UUID NOT NULL REFERENCES shipping.shipping_methods(id),
    rate NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    valid_until TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_shipping_rate_cache UNIQUE (from_postal_code, from_country, to_postal_code, to_country, weight_kg, shipping_method_id)
);

-- Indexes for performance
CREATE INDEX idx_shipping_methods_code ON shipping.shipping_methods(code);
CREATE INDEX idx_shipping_methods_carrier ON shipping.shipping_methods(carrier);
CREATE INDEX idx_shipping_methods_active ON shipping.shipping_methods(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_shipments_order ON shipping.shipments(order_id);
CREATE INDEX idx_shipments_shipment_number ON shipping.shipments(shipment_number);
CREATE INDEX idx_shipments_tracking_number ON shipping.shipments(tracking_number) WHERE tracking_number IS NOT NULL;
CREATE INDEX idx_shipments_status ON shipping.shipments(status);
CREATE INDEX idx_shipments_created ON shipping.shipments(created_at DESC);
CREATE INDEX idx_shipments_carrier ON shipping.shipments(carrier);

CREATE INDEX idx_shipment_tracking_events_shipment ON shipping.shipment_tracking_events(shipment_id);
CREATE INDEX idx_shipment_tracking_events_occurred ON shipping.shipment_tracking_events(occurred_at DESC);

CREATE INDEX idx_delivery_attempts_shipment ON shipping.delivery_attempts(shipment_id);
CREATE INDEX idx_delivery_attempts_attempted ON shipping.delivery_attempts(attempted_at DESC);

CREATE INDEX idx_shipping_rates_cache_lookup ON shipping.shipping_rates_cache(from_postal_code, to_postal_code, weight_kg);
CREATE INDEX idx_shipping_rates_cache_valid_until ON shipping.shipping_rates_cache(valid_until);

-- Comments for documentation
COMMENT ON TABLE shipping.shipping_methods IS 'Available shipping methods and carriers';
COMMENT ON TABLE shipping.shipments IS 'Shipments - Aggregate Root for Shipping Context';
COMMENT ON TABLE shipping.shipment_tracking_events IS 'Tracking events from carriers';
COMMENT ON TABLE shipping.delivery_attempts IS 'Delivery attempt history';
COMMENT ON TABLE shipping.shipping_rates_cache IS 'Cached shipping rates for performance';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION shipping.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_shipping_methods_updated_at
    BEFORE UPDATE ON shipping.shipping_methods
    FOR EACH ROW
    EXECUTE FUNCTION shipping.update_updated_at_column();

CREATE TRIGGER update_shipments_updated_at
    BEFORE UPDATE ON shipping.shipments
    FOR EACH ROW
    EXECUTE FUNCTION shipping.update_updated_at_column();

-- Function to track shipment status changes
CREATE OR REPLACE FUNCTION shipping.track_shipment_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE' AND OLD.status != NEW.status) THEN
        -- Update timestamp fields based on new status
        IF NEW.status = 'LABEL_CREATED' THEN
            NEW.label_created_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'PICKED_UP' THEN
            NEW.picked_up_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'DELIVERED' THEN
            NEW.delivered_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'FAILED' THEN
            NEW.failed_at = CURRENT_TIMESTAMP;
        END IF;

        -- Create a tracking event for status change
        INSERT INTO shipping.shipment_tracking_events (
            shipment_id,
            event_type,
            status,
            occurred_at
        ) VALUES (
            NEW.id,
            'STATUS_CHANGE',
            NEW.status,
            CURRENT_TIMESTAMP
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track status changes
CREATE TRIGGER track_shipment_status_change_trigger
    BEFORE UPDATE ON shipping.shipments
    FOR EACH ROW
    EXECUTE FUNCTION shipping.track_shipment_status_change();

-- Function to generate shipment number
CREATE OR REPLACE FUNCTION shipping.generate_shipment_number()
RETURNS VARCHAR(50) AS $$
DECLARE
    new_shipment_number VARCHAR(50);
    year_month VARCHAR(6);
    sequence_num INTEGER;
BEGIN
    -- Format: SHP-YYYYMM-NNNNN
    year_month := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMM');

    SELECT COALESCE(MAX(SUBSTRING(shipment_number FROM 12)::INTEGER), 0) + 1
    INTO sequence_num
    FROM shipping.shipments
    WHERE shipment_number LIKE 'SHP-' || year_month || '-%';

    new_shipment_number := 'SHP-' || year_month || '-' || LPAD(sequence_num::TEXT, 5, '0');

    RETURN new_shipment_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate shipment number
CREATE OR REPLACE FUNCTION shipping.set_shipment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.shipment_number IS NULL THEN
        NEW.shipment_number = shipping.generate_shipment_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_shipment_number_trigger
    BEFORE INSERT ON shipping.shipments
    FOR EACH ROW
    EXECUTE FUNCTION shipping.set_shipment_number();

-- Function to clean expired rate cache
CREATE OR REPLACE FUNCTION shipping.clean_expired_rate_cache()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM shipping.shipping_rates_cache
    WHERE valid_until < CURRENT_TIMESTAMP;

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
