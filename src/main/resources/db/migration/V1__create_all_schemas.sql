-- ========================================
-- ShopNow Database Schema Creation
-- ========================================
-- This migration creates all schemas for bounded contexts
-- Each bounded context has its own schema to maintain clear separation
-- and respect Domain-Driven Design principles

-- Catalog Context - Product catalog, categories, inventory
CREATE SCHEMA IF NOT EXISTS catalog;

-- Identity & Access Context - Users, authentication, authorization
CREATE SCHEMA IF NOT EXISTS identity;

-- Shopping Context - Cart, wishlist, reviews, feedback
CREATE SCHEMA IF NOT EXISTS shopping;

-- Order Management Context - Orders, order items, returns
CREATE SCHEMA IF NOT EXISTS orders;

-- Payment Context - Payments, transactions, refunds
CREATE SCHEMA IF NOT EXISTS payment;

-- Shipping Context - Addresses, shipping methods, tracking
CREATE SCHEMA IF NOT EXISTS shipping;

-- Promotion Context - Discounts, coupons, promotional banners
CREATE SCHEMA IF NOT EXISTS promotion;

-- Partner Context - Affiliates, suppliers
CREATE SCHEMA IF NOT EXISTS partner;

-- Notification Context - User notifications, alerts
CREATE SCHEMA IF NOT EXISTS notification;

-- Audit Context - Audit logs, activity tracking
CREATE SCHEMA IF NOT EXISTS audit;

-- Events - Domain events for event sourcing
CREATE SCHEMA IF NOT EXISTS events;

-- Grant permissions (adjust based on your environment)
-- GRANT ALL PRIVILEGES ON SCHEMA catalog TO shopnow;
-- GRANT ALL PRIVILEGES ON SCHEMA identity TO shopnow;
-- ... (repeat for all schemas if needed)

-- Comments for documentation
COMMENT ON SCHEMA catalog IS 'Catalog Bounded Context - Products, categories, and inventory management';
COMMENT ON SCHEMA identity IS 'Identity & Access Bounded Context - User management and authentication';
COMMENT ON SCHEMA shopping IS 'Shopping Bounded Context - Cart, wishlist, and reviews';
COMMENT ON SCHEMA orders IS 'Order Management Bounded Context - Order lifecycle and returns';
COMMENT ON SCHEMA payment IS 'Payment Bounded Context - Payment processing and transactions';
COMMENT ON SCHEMA shipping IS 'Shipping Bounded Context - Address and shipping management';
COMMENT ON SCHEMA promotion IS 'Promotion Bounded Context - Discounts, coupons, and campaigns';
COMMENT ON SCHEMA partner IS 'Partner Bounded Context - Affiliates and suppliers';
COMMENT ON SCHEMA notification IS 'Notification Bounded Context - User notifications';
COMMENT ON SCHEMA audit IS 'Audit Bounded Context - System audit logs';
COMMENT ON SCHEMA events IS 'Event Store - Domain events for event sourcing';
