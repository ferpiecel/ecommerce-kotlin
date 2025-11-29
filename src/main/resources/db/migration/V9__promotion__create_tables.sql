-- ========================================
-- Promotion Context - Tables Creation
-- ========================================
-- Bounded Context: Promotion
-- Aggregates: Coupon, Promotion
-- Purpose: Discounts, coupons, and promotional campaigns

-- Promotions Table (Aggregate Root)
CREATE TABLE promotion.promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,

    -- Promotion type and rules
    promotion_type VARCHAR(30) NOT NULL
        CHECK (promotion_type IN ('PERCENTAGE', 'FIXED_AMOUNT', 'FREE_SHIPPING', 'BUY_X_GET_Y', 'BUNDLE')),
    discount_percentage NUMERIC(5, 2) CHECK (discount_percentage >= 0 AND discount_percentage <= 100),
    discount_amount NUMERIC(10, 2) CHECK (discount_amount >= 0),
    currency VARCHAR(3) DEFAULT 'USD',

    -- Applicability
    applies_to VARCHAR(20) NOT NULL CHECK (applies_to IN ('ORDER', 'PRODUCT', 'CATEGORY', 'SHIPPING')),
    applicable_product_ids UUID[], -- Array of product IDs
    applicable_category_ids UUID[], -- Array of category IDs

    -- Usage limits
    max_uses INTEGER, -- Total uses allowed
    max_uses_per_user INTEGER, -- Per user limit
    current_uses INTEGER DEFAULT 0 CHECK (current_uses >= 0),
    minimum_order_amount NUMERIC(10, 2) CHECK (minimum_order_amount >= 0),
    maximum_discount_amount NUMERIC(10, 2) CHECK (maximum_discount_amount >= 0),

    -- Status and validity
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'ACTIVE', 'PAUSED', 'EXPIRED', 'CANCELLED')),
    is_public BOOLEAN DEFAULT TRUE,
    requires_code BOOLEAN DEFAULT TRUE,

    -- Time restrictions
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,

    -- Metadata
    priority INTEGER DEFAULT 0, -- For stacking promotions
    stackable BOOLEAN DEFAULT FALSE, -- Can be combined with other promotions
    created_by UUID, -- Reference to identity.users
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Coupons Table (Aggregate Root)
CREATE TABLE promotion.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL UNIQUE,
    promotion_id UUID REFERENCES promotion.promotions(id),

    -- Coupon type
    coupon_type VARCHAR(30) NOT NULL CHECK (coupon_type IN ('SINGLE_USE', 'MULTI_USE', 'USER_SPECIFIC')),

    -- Assignment
    assigned_to_user_id UUID, -- Reference to identity.users (for user-specific coupons)
    assigned_to_email VARCHAR(100),

    -- Usage tracking
    max_uses INTEGER DEFAULT 1,
    current_uses INTEGER DEFAULT 0 CHECK (current_uses >= 0),

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'USED', 'EXPIRED', 'CANCELLED')),

    -- Time restrictions
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    first_used_at TIMESTAMP,
    last_used_at TIMESTAMP
);

-- Promotion Usage Table (tracking who used what)
CREATE TABLE promotion.promotion_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotion.promotions(id),
    coupon_id UUID REFERENCES promotion.coupons(id),
    order_id UUID NOT NULL, -- Reference to orders.orders
    user_id UUID NOT NULL, -- Reference to identity.users

    -- Discount applied
    discount_amount NUMERIC(10, 2) NOT NULL CHECK (discount_amount >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',

    -- Metadata
    used_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Promotion Rules Table (complex rules engine)
CREATE TABLE promotion.promotion_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotion.promotions(id) ON DELETE CASCADE,
    rule_type VARCHAR(30) NOT NULL
        CHECK (rule_type IN ('MINIMUM_QUANTITY', 'PRODUCT_IN_CART', 'CATEGORY_IN_CART', 'USER_SEGMENT', 'DAY_OF_WEEK', 'TIME_OF_DAY')),
    rule_config JSONB NOT NULL, -- Flexible JSON configuration for different rule types
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Promotional Campaigns Table
CREATE TABLE promotion.campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    description TEXT,
    campaign_type VARCHAR(30) CHECK (campaign_type IN ('SEASONAL', 'FLASH_SALE', 'LOYALTY', 'REFERRAL', 'ABANDONED_CART')),

    -- Associated promotions
    promotion_ids UUID[], -- Array of promotion IDs

    -- Status and timing
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'SCHEDULED', 'ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED')),
    starts_at TIMESTAMP NOT NULL,
    ends_at TIMESTAMP,

    -- Metrics
    target_revenue NUMERIC(12, 2),
    target_orders INTEGER,
    actual_revenue NUMERIC(12, 2) DEFAULT 0,
    actual_orders INTEGER DEFAULT 0,

    created_by UUID, -- Reference to identity.users
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_promotions_code ON promotion.promotions(code);
CREATE INDEX idx_promotions_status ON promotion.promotions(status);
CREATE INDEX idx_promotions_valid_from ON promotion.promotions(valid_from);
CREATE INDEX idx_promotions_valid_until ON promotion.promotions(valid_until);
CREATE INDEX idx_promotions_type ON promotion.promotions(promotion_type);
CREATE INDEX idx_promotions_active ON promotion.promotions(status, valid_from, valid_until)
    WHERE status = 'ACTIVE';

CREATE INDEX idx_coupons_code ON promotion.coupons(code);
CREATE INDEX idx_coupons_promotion ON promotion.coupons(promotion_id);
CREATE INDEX idx_coupons_user ON promotion.coupons(assigned_to_user_id) WHERE assigned_to_user_id IS NOT NULL;
CREATE INDEX idx_coupons_email ON promotion.coupons(assigned_to_email) WHERE assigned_to_email IS NOT NULL;
CREATE INDEX idx_coupons_status ON promotion.coupons(status);

CREATE INDEX idx_promotion_usage_promotion ON promotion.promotion_usage(promotion_id);
CREATE INDEX idx_promotion_usage_coupon ON promotion.promotion_usage(coupon_id);
CREATE INDEX idx_promotion_usage_order ON promotion.promotion_usage(order_id);
CREATE INDEX idx_promotion_usage_user ON promotion.promotion_usage(user_id);
CREATE INDEX idx_promotion_usage_used ON promotion.promotion_usage(used_at DESC);

CREATE INDEX idx_promotion_rules_promotion ON promotion.promotion_rules(promotion_id);
CREATE INDEX idx_promotion_rules_type ON promotion.promotion_rules(rule_type);
CREATE INDEX idx_promotion_rules_config ON promotion.promotion_rules USING gin(rule_config);

CREATE INDEX idx_campaigns_status ON promotion.campaigns(status);
CREATE INDEX idx_campaigns_starts ON promotion.campaigns(starts_at);
CREATE INDEX idx_campaigns_type ON promotion.campaigns(campaign_type);

-- Comments for documentation
COMMENT ON TABLE promotion.promotions IS 'Promotions and discounts - Aggregate Root';
COMMENT ON TABLE promotion.coupons IS 'Coupon codes - Aggregate Root';
COMMENT ON TABLE promotion.promotion_usage IS 'Tracking of promotion usage per order';
COMMENT ON TABLE promotion.promotion_rules IS 'Complex promotion rules and conditions';
COMMENT ON TABLE promotion.campaigns IS 'Marketing campaigns grouping multiple promotions';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION promotion.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_promotions_updated_at
    BEFORE UPDATE ON promotion.promotions
    FOR EACH ROW
    EXECUTE FUNCTION promotion.update_updated_at_column();

CREATE TRIGGER update_coupons_updated_at
    BEFORE UPDATE ON promotion.coupons
    FOR EACH ROW
    EXECUTE FUNCTION promotion.update_updated_at_column();

CREATE TRIGGER update_campaigns_updated_at
    BEFORE UPDATE ON promotion.campaigns
    FOR EACH ROW
    EXECUTE FUNCTION promotion.update_updated_at_column();

-- Function to track promotion usage
CREATE OR REPLACE FUNCTION promotion.track_promotion_usage()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Increment promotion usage count
        UPDATE promotion.promotions
        SET current_uses = current_uses + 1
        WHERE id = NEW.promotion_id;

        -- Increment coupon usage count if applicable
        IF NEW.coupon_id IS NOT NULL THEN
            UPDATE promotion.coupons
            SET current_uses = current_uses + 1,
                first_used_at = CASE WHEN first_used_at IS NULL THEN CURRENT_TIMESTAMP ELSE first_used_at END,
                last_used_at = CURRENT_TIMESTAMP
            WHERE id = NEW.coupon_id;

            -- Update coupon status if max uses reached
            UPDATE promotion.coupons
            SET status = 'USED'
            WHERE id = NEW.coupon_id
              AND current_uses >= max_uses
              AND status = 'ACTIVE';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track usage
CREATE TRIGGER track_promotion_usage_trigger
    AFTER INSERT ON promotion.promotion_usage
    FOR EACH ROW
    EXECUTE FUNCTION promotion.track_promotion_usage();

-- Function to validate promotion is still available
CREATE OR REPLACE FUNCTION promotion.is_promotion_valid(promotion_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    promo RECORD;
    is_valid BOOLEAN;
BEGIN
    SELECT * INTO promo
    FROM promotion.promotions
    WHERE id = promotion_id;

    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Check status
    IF promo.status != 'ACTIVE' THEN
        RETURN FALSE;
    END IF;

    -- Check time validity
    IF promo.valid_from > CURRENT_TIMESTAMP THEN
        RETURN FALSE;
    END IF;

    IF promo.valid_until IS NOT NULL AND promo.valid_until < CURRENT_TIMESTAMP THEN
        RETURN FALSE;
    END IF;

    -- Check max uses
    IF promo.max_uses IS NOT NULL AND promo.current_uses >= promo.max_uses THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
