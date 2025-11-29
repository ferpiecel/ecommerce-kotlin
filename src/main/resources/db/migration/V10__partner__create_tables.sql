-- ========================================
-- Partner Context - Tables Creation
-- ========================================
-- Bounded Context: Partner
-- Aggregates: Partner, Affiliate
-- Purpose: Partner and affiliate management

-- Partners Table (Aggregate Root)
CREATE TABLE partner.partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_code VARCHAR(50) NOT NULL UNIQUE,
    partner_type VARCHAR(30) NOT NULL CHECK (partner_type IN ('SUPPLIER', 'AFFILIATE', 'MARKETPLACE', 'DROPSHIPPER')),

    -- Company details
    company_name VARCHAR(150) NOT NULL,
    legal_name VARCHAR(200),
    tax_id VARCHAR(50),
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    website VARCHAR(200),

    -- Contact person
    contact_name VARCHAR(100),
    contact_email VARCHAR(100),
    contact_phone VARCHAR(20),

    -- Address
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(2),

    -- Business terms
    commission_rate NUMERIC(5, 2) DEFAULT 0 CHECK (commission_rate >= 0 AND commission_rate <= 100),
    payment_terms VARCHAR(20) CHECK (payment_terms IN ('NET_7', 'NET_15', 'NET_30', 'NET_60', 'IMMEDIATE')),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'TERMINATED')),
    tier VARCHAR(20) CHECK (tier IN ('BRONZE', 'SILVER', 'GOLD', 'PLATINUM')),

    -- Metadata
    notes TEXT,
    contract_url VARCHAR(500),

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activated_at TIMESTAMP,
    terminated_at TIMESTAMP
);

-- Partner Products Table (products provided by partners)
CREATE TABLE partner.partner_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partner.partners(id) ON DELETE CASCADE,
    product_id UUID NOT NULL, -- Reference to catalog.products

    -- Pricing
    partner_cost NUMERIC(10, 2) NOT NULL CHECK (partner_cost >= 0),
    suggested_retail_price NUMERIC(10, 2) CHECK (suggested_retail_price >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Inventory from partner
    available_quantity INTEGER DEFAULT 0 CHECK (available_quantity >= 0),
    lead_time_days INTEGER DEFAULT 0 CHECK (lead_time_days >= 0),

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_sync_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_partner_product UNIQUE (partner_id, product_id)
);

-- Affiliate Links Table
CREATE TABLE partner.affiliate_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partner.partners(id) ON DELETE CASCADE,
    link_code VARCHAR(100) NOT NULL UNIQUE,
    target_url VARCHAR(500) NOT NULL,
    product_id UUID, -- Reference to catalog.products (optional, for specific product links)
    campaign_name VARCHAR(100),

    -- Tracking
    click_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    total_revenue NUMERIC(12, 2) DEFAULT 0,
    total_commission NUMERIC(12, 2) DEFAULT 0,

    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP
);

-- Affiliate Clicks Table (tracking)
CREATE TABLE partner.affiliate_clicks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    affiliate_link_id UUID NOT NULL REFERENCES partner.affiliate_links(id) ON DELETE CASCADE,
    session_id VARCHAR(100),
    ip_address INET,
    user_agent TEXT,
    referrer VARCHAR(500),
    clicked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    converted BOOLEAN DEFAULT FALSE,
    order_id UUID, -- Reference to orders.orders (when converted)
    conversion_date TIMESTAMP
);

-- Partner Commissions Table
CREATE TABLE partner.partner_commissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partner.partners(id),
    order_id UUID NOT NULL, -- Reference to orders.orders
    affiliate_link_id UUID REFERENCES partner.affiliate_links(id),

    -- Commission details
    commission_type VARCHAR(30) CHECK (commission_type IN ('PERCENTAGE', 'FIXED', 'TIERED')),
    commission_rate NUMERIC(5, 2),
    order_amount NUMERIC(12, 2) NOT NULL,
    commission_amount NUMERIC(12, 2) NOT NULL CHECK (commission_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Payment status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'PAID', 'CANCELLED', 'DISPUTED')),

    -- Metadata
    notes TEXT,
    earned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP,
    paid_at TIMESTAMP,
    payment_reference VARCHAR(100)
);

-- Partner Payouts Table
CREATE TABLE partner.partner_payouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES partner.partners(id),
    payout_number VARCHAR(50) NOT NULL UNIQUE,

    -- Payout details
    total_amount NUMERIC(12, 2) NOT NULL CHECK (total_amount > 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    commission_ids UUID[], -- Array of commission IDs included in this payout

    -- Payment method
    payment_method VARCHAR(30) CHECK (payment_method IN ('BANK_TRANSFER', 'PAYPAL', 'CHECK', 'WIRE_TRANSFER')),
    payment_details JSONB,

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')),

    -- Metadata
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    completed_at TIMESTAMP,
    payment_reference VARCHAR(100)
);

-- Indexes for performance
CREATE INDEX idx_partners_partner_code ON partner.partners(partner_code);
CREATE INDEX idx_partners_type ON partner.partners(partner_type);
CREATE INDEX idx_partners_status ON partner.partners(status);
CREATE INDEX idx_partners_email ON partner.partners(email);

CREATE INDEX idx_partner_products_partner ON partner.partner_products(partner_id);
CREATE INDEX idx_partner_products_product ON partner.partner_products(product_id);
CREATE INDEX idx_partner_products_active ON partner.partner_products(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_affiliate_links_partner ON partner.affiliate_links(partner_id);
CREATE INDEX idx_affiliate_links_code ON partner.affiliate_links(link_code);
CREATE INDEX idx_affiliate_links_product ON partner.affiliate_links(product_id) WHERE product_id IS NOT NULL;
CREATE INDEX idx_affiliate_links_active ON partner.affiliate_links(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_affiliate_clicks_link ON partner.affiliate_clicks(affiliate_link_id);
CREATE INDEX idx_affiliate_clicks_session ON partner.affiliate_clicks(session_id);
CREATE INDEX idx_affiliate_clicks_clicked ON partner.affiliate_clicks(clicked_at DESC);
CREATE INDEX idx_affiliate_clicks_converted ON partner.affiliate_clicks(converted) WHERE converted = TRUE;

CREATE INDEX idx_partner_commissions_partner ON partner.partner_commissions(partner_id);
CREATE INDEX idx_partner_commissions_order ON partner.partner_commissions(order_id);
CREATE INDEX idx_partner_commissions_link ON partner.partner_commissions(affiliate_link_id);
CREATE INDEX idx_partner_commissions_status ON partner.partner_commissions(status);
CREATE INDEX idx_partner_commissions_earned ON partner.partner_commissions(earned_at DESC);

CREATE INDEX idx_partner_payouts_partner ON partner.partner_payouts(partner_id);
CREATE INDEX idx_partner_payouts_number ON partner.partner_payouts(payout_number);
CREATE INDEX idx_partner_payouts_status ON partner.partner_payouts(status);

-- Comments for documentation
COMMENT ON TABLE partner.partners IS 'Partners and affiliates - Aggregate Root';
COMMENT ON TABLE partner.partner_products IS 'Products provided by partners (suppliers/dropshippers)';
COMMENT ON TABLE partner.affiliate_links IS 'Affiliate tracking links';
COMMENT ON TABLE partner.affiliate_clicks IS 'Affiliate click tracking';
COMMENT ON TABLE partner.partner_commissions IS 'Partner commissions earned';
COMMENT ON TABLE partner.partner_payouts IS 'Payouts made to partners';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION partner.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_partners_updated_at
    BEFORE UPDATE ON partner.partners
    FOR EACH ROW
    EXECUTE FUNCTION partner.update_updated_at_column();

CREATE TRIGGER update_partner_products_updated_at
    BEFORE UPDATE ON partner.partner_products
    FOR EACH ROW
    EXECUTE FUNCTION partner.update_updated_at_column();

-- Function to track affiliate click conversion
CREATE OR REPLACE FUNCTION partner.track_affiliate_conversion()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.converted = FALSE AND NEW.converted = TRUE THEN
        -- Update affiliate link statistics
        UPDATE partner.affiliate_links
        SET conversion_count = conversion_count + 1
        WHERE id = NEW.affiliate_link_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track conversions
CREATE TRIGGER track_affiliate_conversion_trigger
    AFTER UPDATE ON partner.affiliate_clicks
    FOR EACH ROW
    EXECUTE FUNCTION partner.track_affiliate_conversion();

-- Function to generate payout number
CREATE OR REPLACE FUNCTION partner.generate_payout_number()
RETURNS VARCHAR(50) AS $$
DECLARE
    new_payout_number VARCHAR(50);
    year_month VARCHAR(6);
    sequence_num INTEGER;
BEGIN
    -- Format: PAYOUT-YYYYMM-NNNNN
    year_month := TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMM');

    SELECT COALESCE(MAX(SUBSTRING(payout_number FROM 15)::INTEGER), 0) + 1
    INTO sequence_num
    FROM partner.partner_payouts
    WHERE payout_number LIKE 'PAYOUT-' || year_month || '-%';

    new_payout_number := 'PAYOUT-' || year_month || '-' || LPAD(sequence_num::TEXT, 5, '0');

    RETURN new_payout_number;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate payout number
CREATE OR REPLACE FUNCTION partner.set_payout_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payout_number IS NULL THEN
        NEW.payout_number = partner.generate_payout_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_payout_number_trigger
    BEFORE INSERT ON partner.partner_payouts
    FOR EACH ROW
    EXECUTE FUNCTION partner.set_payout_number();
