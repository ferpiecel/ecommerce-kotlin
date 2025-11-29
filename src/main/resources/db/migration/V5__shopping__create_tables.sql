-- ========================================
-- Shopping Context - Tables Creation
-- ========================================
-- Bounded Context: Shopping
-- Aggregates: ShoppingCart, Wishlist, Review
-- Purpose: Shopping cart management, wishlists, and product reviews

-- Shopping Carts Table (Aggregate Root)
CREATE TABLE shopping.shopping_carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Reference to identity.users
    session_id VARCHAR(100), -- For anonymous users
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'ABANDONED', 'CONVERTED', 'MERGED')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,

    CONSTRAINT uq_cart_user UNIQUE (user_id, status)
);

-- Partial unique index to ensure only one active cart per user
CREATE UNIQUE INDEX uq_active_cart_user ON shopping.shopping_carts (user_id)
    WHERE status = 'ACTIVE' AND user_id IS NOT NULL;

CREATE UNIQUE INDEX uq_active_cart_session ON shopping.shopping_carts (session_id)
    WHERE status = 'ACTIVE' AND session_id IS NOT NULL;

-- Cart Items Table (Entity within ShoppingCart aggregate)
CREATE TABLE shopping.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES shopping.shopping_carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL, -- Reference to catalog.products
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_cart_product UNIQUE (cart_id, product_id)
);

-- Wishlists Table (Aggregate Root)
CREATE TABLE shopping.wishlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, -- Reference to identity.users
    name VARCHAR(100) NOT NULL DEFAULT 'My Wishlist',
    description TEXT,
    visibility VARCHAR(20) NOT NULL DEFAULT 'PRIVATE' CHECK (visibility IN ('PRIVATE', 'PUBLIC', 'SHARED')),
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_wishlist_user_name UNIQUE (user_id, name)
);

-- Partial unique index to ensure only one default wishlist per user
CREATE UNIQUE INDEX uq_default_wishlist_user ON shopping.wishlists (user_id)
    WHERE is_default = TRUE;

-- Wishlist Items Table (Entity within Wishlist aggregate)
CREATE TABLE shopping.wishlist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wishlist_id UUID NOT NULL REFERENCES shopping.wishlists(id) ON DELETE CASCADE,
    product_id UUID NOT NULL, -- Reference to catalog.products
    priority INTEGER DEFAULT 0,
    notes TEXT,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_wishlist_product UNIQUE (wishlist_id, product_id)
);

-- Product Reviews Table (Aggregate Root)
CREATE TABLE shopping.product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL, -- Reference to catalog.products
    user_id UUID NOT NULL, -- Reference to identity.users
    order_id UUID, -- Reference to orders.orders (optional - verified purchase)
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title VARCHAR(150),
    comment TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'FLAGGED')),
    verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_review_user_product UNIQUE (user_id, product_id)
);

-- Review Votes Table (for helpful/not helpful votes)
CREATE TABLE shopping.review_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES shopping.product_reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL, -- Reference to identity.users
    vote_type VARCHAR(10) NOT NULL CHECK (vote_type IN ('HELPFUL', 'NOT_HELPFUL')),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_vote_user_review UNIQUE (user_id, review_id)
);

-- Indexes for performance
CREATE INDEX idx_shopping_carts_user ON shopping.shopping_carts(user_id);
CREATE INDEX idx_shopping_carts_session ON shopping.shopping_carts(session_id);
CREATE INDEX idx_shopping_carts_status ON shopping.shopping_carts(status);
CREATE INDEX idx_shopping_carts_expires ON shopping.shopping_carts(expires_at) WHERE expires_at IS NOT NULL;

CREATE INDEX idx_cart_items_cart ON shopping.cart_items(cart_id);
CREATE INDEX idx_cart_items_product ON shopping.cart_items(product_id);

CREATE INDEX idx_wishlists_user ON shopping.wishlists(user_id);
CREATE INDEX idx_wishlists_visibility ON shopping.wishlists(visibility) WHERE visibility = 'PUBLIC';

CREATE INDEX idx_wishlist_items_wishlist ON shopping.wishlist_items(wishlist_id);
CREATE INDEX idx_wishlist_items_product ON shopping.wishlist_items(product_id);

CREATE INDEX idx_product_reviews_product ON shopping.product_reviews(product_id);
CREATE INDEX idx_product_reviews_user ON shopping.product_reviews(user_id);
CREATE INDEX idx_product_reviews_status ON shopping.product_reviews(status);
CREATE INDEX idx_product_reviews_rating ON shopping.product_reviews(rating);
CREATE INDEX idx_product_reviews_verified ON shopping.product_reviews(verified_purchase) WHERE verified_purchase = TRUE;

CREATE INDEX idx_review_votes_review ON shopping.review_votes(review_id);
CREATE INDEX idx_review_votes_user ON shopping.review_votes(user_id);

-- Full-text search for reviews
CREATE INDEX idx_reviews_comment_search ON shopping.product_reviews USING gin(to_tsvector('english', comment));

-- Comments for documentation
COMMENT ON TABLE shopping.shopping_carts IS 'Shopping carts - Aggregate Root for Shopping Context';
COMMENT ON TABLE shopping.cart_items IS 'Cart items - Entity within ShoppingCart aggregate';
COMMENT ON TABLE shopping.wishlists IS 'User wishlists - Aggregate Root';
COMMENT ON TABLE shopping.wishlist_items IS 'Wishlist items - Entity within Wishlist aggregate';
COMMENT ON TABLE shopping.product_reviews IS 'Product reviews and ratings - Aggregate Root';
COMMENT ON TABLE shopping.review_votes IS 'Helpful/not helpful votes on reviews';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION shopping.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_shopping_carts_updated_at
    BEFORE UPDATE ON shopping.shopping_carts
    FOR EACH ROW
    EXECUTE FUNCTION shopping.update_updated_at_column();

CREATE TRIGGER update_cart_items_updated_at
    BEFORE UPDATE ON shopping.cart_items
    FOR EACH ROW
    EXECUTE FUNCTION shopping.update_updated_at_column();

CREATE TRIGGER update_wishlists_updated_at
    BEFORE UPDATE ON shopping.wishlists
    FOR EACH ROW
    EXECUTE FUNCTION shopping.update_updated_at_column();

CREATE TRIGGER update_product_reviews_updated_at
    BEFORE UPDATE ON shopping.product_reviews
    FOR EACH ROW
    EXECUTE FUNCTION shopping.update_updated_at_column();

-- Function to update review helpful count
CREATE OR REPLACE FUNCTION shopping.update_review_helpful_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.vote_type = 'HELPFUL' THEN
            UPDATE shopping.product_reviews
            SET helpful_count = helpful_count + 1
            WHERE id = NEW.review_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.vote_type = 'HELPFUL' AND NEW.vote_type = 'NOT_HELPFUL' THEN
            UPDATE shopping.product_reviews
            SET helpful_count = helpful_count - 1
            WHERE id = NEW.review_id;
        ELSIF OLD.vote_type = 'NOT_HELPFUL' AND NEW.vote_type = 'HELPFUL' THEN
            UPDATE shopping.product_reviews
            SET helpful_count = helpful_count + 1
            WHERE id = NEW.review_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.vote_type = 'HELPFUL' THEN
            UPDATE shopping.product_reviews
            SET helpful_count = helpful_count - 1
            WHERE id = OLD.review_id;
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update helpful count
CREATE TRIGGER update_review_helpful_count_trigger
    AFTER INSERT OR UPDATE OR DELETE ON shopping.review_votes
    FOR EACH ROW
    EXECUTE FUNCTION shopping.update_review_helpful_count();
