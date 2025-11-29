-- ========================================
-- Catalog Context - Tables Creation
-- ========================================
-- Bounded Context: Catalog
-- Aggregates: Product, Category
-- Purpose: Product catalog, categories, and inventory management

-- Categories Table (Aggregate Root)
CREATE TABLE catalog.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES catalog.categories(id) ON DELETE SET NULL,
    slug VARCHAR(150) NOT NULL,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_category_slug UNIQUE (slug),
    CONSTRAINT uq_category_name_parent UNIQUE (name, parent_id)
);

-- Products Table (Aggregate Root)
CREATE TABLE catalog.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    currency VARCHAR(3) NOT NULL DEFAULT 'USD',
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    category_id UUID NOT NULL REFERENCES catalog.categories(id) ON DELETE RESTRICT,
    slug VARCHAR(200) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT uq_product_slug UNIQUE (slug)
);

-- Product Images Table (Entity within Product aggregate)
CREATE TABLE catalog.product_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES catalog.products(id) ON DELETE CASCADE,
    url VARCHAR(500) NOT NULL,
    alt_text VARCHAR(255),
    display_order INTEGER NOT NULL DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Partial unique index to ensure only one primary image per product
CREATE UNIQUE INDEX uq_product_primary_image ON catalog.product_images (product_id) WHERE is_primary = TRUE;

-- Inventory Management Table (Entity for stock tracking)
CREATE TABLE catalog.inventory_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES catalog.products(id) ON DELETE CASCADE,
    movement_type VARCHAR(20) NOT NULL CHECK (movement_type IN ('IN', 'OUT', 'ADJUSTMENT', 'RESERVED', 'RELEASED')),
    quantity INTEGER NOT NULL,
    previous_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    reason TEXT,
    reference_id UUID, -- Could be order_id, return_id, etc.
    reference_type VARCHAR(50), -- 'ORDER', 'RETURN', 'MANUAL', etc.
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by UUID -- User or system ID
);

-- Indexes for performance
CREATE INDEX idx_categories_parent ON catalog.categories(parent_id);
CREATE INDEX idx_categories_active ON catalog.categories(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_products_category ON catalog.products(category_id);
CREATE INDEX idx_products_sku ON catalog.products(sku);
CREATE INDEX idx_products_active ON catalog.products(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_products_featured ON catalog.products(is_featured) WHERE is_featured = TRUE;
CREATE INDEX idx_products_price ON catalog.products(price);
CREATE INDEX idx_product_images_product ON catalog.product_images(product_id);
CREATE INDEX idx_inventory_movements_product ON catalog.inventory_movements(product_id);
CREATE INDEX idx_inventory_movements_created ON catalog.inventory_movements(created_at DESC);

-- Full-text search index for products
CREATE INDEX idx_products_name_search ON catalog.products USING gin(to_tsvector('english', name));
CREATE INDEX idx_products_description_search ON catalog.products USING gin(to_tsvector('english', description));

-- Comments for documentation
COMMENT ON TABLE catalog.categories IS 'Product categories with hierarchical structure';
COMMENT ON TABLE catalog.products IS 'Product catalog - Aggregate Root for Catalog Context';
COMMENT ON TABLE catalog.product_images IS 'Product images - Entity within Product aggregate';
COMMENT ON TABLE catalog.inventory_movements IS 'Inventory movement history for audit and tracking';

COMMENT ON COLUMN catalog.products.sku IS 'Stock Keeping Unit - unique product identifier';
COMMENT ON COLUMN catalog.products.slug IS 'URL-friendly product identifier';
COMMENT ON COLUMN catalog.inventory_movements.movement_type IS 'Type of inventory movement: IN, OUT, ADJUSTMENT, RESERVED, RELEASED';
COMMENT ON COLUMN catalog.inventory_movements.reference_id IS 'Reference to related entity (order_id, return_id, etc.)';

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION catalog.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE ON catalog.categories
    FOR EACH ROW
    EXECUTE FUNCTION catalog.update_updated_at_column();

CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON catalog.products
    FOR EACH ROW
    EXECUTE FUNCTION catalog.update_updated_at_column();

-- Function to track inventory movements
CREATE OR REPLACE FUNCTION catalog.track_inventory_movement()
RETURNS TRIGGER AS $$
BEGIN
    -- When stock_quantity changes, create an inventory movement record
    IF (TG_OP = 'UPDATE' AND OLD.stock_quantity != NEW.stock_quantity) THEN
        INSERT INTO catalog.inventory_movements (
            product_id,
            movement_type,
            quantity,
            previous_quantity,
            new_quantity,
            reason
        ) VALUES (
            NEW.id,
            CASE
                WHEN NEW.stock_quantity > OLD.stock_quantity THEN 'IN'
                ELSE 'OUT'
            END,
            ABS(NEW.stock_quantity - OLD.stock_quantity),
            OLD.stock_quantity,
            NEW.stock_quantity,
            'Stock quantity updated'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-track inventory movements
CREATE TRIGGER track_product_inventory_movement
    AFTER UPDATE ON catalog.products
    FOR EACH ROW
    EXECUTE FUNCTION catalog.track_inventory_movement();
