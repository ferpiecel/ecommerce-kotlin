-- Esquema inicial provisto (manteniendo comillas y tipos decimal)
CREATE TABLE "Addresses" (
  "address_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "street_address" varchar(150),
  "city" varchar(100),
  "state_province" varchar(50),
  "postal_code" varchar(20),
  "country" varchar(100)
);
CREATE TABLE "ProductImages" (
  "image_id" varchar(36) PRIMARY KEY,
  "product_id" varchar(36),
  "image_url" varchar(255),
  "alt_text" varchar(255)
);
CREATE TABLE "WishlistItems" (
  "wishlist_item_id" varchar(36) PRIMARY KEY,
  "wishlist_id" varchar(36),
  "product_id" varchar(36)
);
CREATE TABLE "Feedback" (
  "feedback_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "feedback_text" text,
  "feedback_date" timestamp
);
CREATE TABLE "Orders" (
  "order_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "order_date" timestamp,
  "total_amount" decimal(10, 2),
  "status" varchar(50),
  "shipping_address_id" varchar(36),
  "billing_address_id" varchar(36)
);
CREATE TABLE "CartItems" (
  "cart_item_id" varchar(36) PRIMARY KEY,
  "cart_id" varchar(36),
  "product_id" varchar(36),
  "quantity" int
);
CREATE TABLE "UserRoleAssignments" (
  "user_role_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "role_id" varchar(36),
  "assignment_date" timestamp
);
CREATE TABLE "Users" (
  "user_id" varchar(36) PRIMARY KEY,
  "username" varchar(50),
  "password_hash" varchar(255),
  "email" varchar(100),
  "first_name" varchar(50),
  "last_name" varchar(50),
  "dob" date,
  "registration_date" timestamp,
  "last_login_date" timestamp
);
CREATE TABLE "UserRoles" (
  "role_id" varchar(36) PRIMARY KEY,
  "role_name" varchar(100)
);
CREATE TABLE "AuditLogs" (
  "audit_log_id" varchar(36) PRIMARY KEY,
  "action_by" varchar(36),
  "action" varchar(255),
  "action_date" timestamp,
  "details" text
);
CREATE TABLE "Discounts" (
  "discount_id" varchar(36) PRIMARY KEY,
  "product_id" varchar(36),
  "discount_percentage" decimal(5, 2),
  "start_date" date,
  "end_date" date
);
CREATE TABLE "PaymentMethods" (
  "payment_method_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "card_number" varchar(16),
  "cardholder_name" varchar(100),
  "expiration_date" date,
  "security_code" varchar(4)
);
CREATE TABLE "Admins" (
  "admin_id" varchar(36) PRIMARY KEY,
  "admin_username" varchar(50),
  "admin_password_hash" varchar(255),
  "email" varchar(100),
  "first_name" varchar(50),
  "last_name" varchar(50),
  "role" varchar(50),
  "registration_date" timestamp
);
CREATE TABLE "ProductSuppliers" (
  "product_supplier_id" varchar(36) PRIMARY KEY,
  "product_id" varchar(36),
  "supplier_id" varchar(36),
  "supply_price" decimal(10, 2)
);
CREATE TABLE "Reviews" (
  "review_id" varchar(36) PRIMARY KEY,
  "product_id" varchar(36),
  "user_id" varchar(36),
  "rating" int,
  "review_text" text,
  "review_date" timestamp
);
CREATE TABLE "Taxes" (
  "tax_id" varchar(36) PRIMARY KEY,
  "tax_name" varchar(100),
  "tax_percentage" decimal(5, 2),
  "applicable_from" date,
  "applicable_until" date
);
CREATE TABLE "ShippingMethods" (
  "shipping_method_id" varchar(36) PRIMARY KEY,
  "method_name" varchar(100),
  "method_description" text,
  "cost" decimal(10, 2)
);
CREATE TABLE "Coupons" (
  "coupon_id" varchar(36) PRIMARY KEY,
  "coupon_code" varchar(20),
  "discount_percentage" decimal(5, 2),
  "expiration_date" date,
  "min_purchase_amount" decimal(10, 2)
);
CREATE TABLE "UserCoupons" (
  "user_coupon_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "coupon_id" varchar(36),
  "applied_date" timestamp
);
CREATE TABLE "Returns" (
  "return_id" varchar(36) PRIMARY KEY,
  "order_id" varchar(36),
  "product_id" varchar(36),
  "return_reason" text,
  "return_date" timestamp,
  "status" varchar(50)
);
CREATE TABLE "Wishlist" (
  "wishlist_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "wishlist_date" timestamp
);
CREATE TABLE "AffiliateSales" (
  "affiliate_sale_id" varchar(36) PRIMARY KEY,
  "affiliate_id" varchar(36),
  "order_id" varchar(36),
  "commission_amount" decimal(10, 2),
  "sale_date" timestamp
);
CREATE TABLE "Cart" (
  "cart_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "creation_date" timestamp
);
CREATE TABLE "ShippingDetails" (
  "shipping_id" varchar(36) PRIMARY KEY,
  "order_id" varchar(36),
  "shipping_method_id" varchar(36),
  "tracking_number" varchar(50),
  "shipping_date" timestamp,
  "delivery_date" timestamp
);
CREATE TABLE "Affiliates" (
  "affiliate_id" varchar(36) PRIMARY KEY,
  "affiliate_name" varchar(100),
  "contact_email" varchar(100),
  "commission_percentage" decimal(5, 2)
);
CREATE TABLE "Notifications" (
  "notification_id" varchar(36) PRIMARY KEY,
  "user_id" varchar(36),
  "notification_text" text,
  "notification_date" timestamp,
  "is_read" boolean
);
CREATE TABLE "OrderTaxes" (
  "order_tax_id" varchar(36) PRIMARY KEY,
  "order_id" varchar(36),
  "tax_amount" decimal(10, 2),
  "tax_id" varchar(36)
);
CREATE TABLE "Categories" (
  "category_id" varchar(36) PRIMARY KEY,
  "category_name" varchar(100),
  "category_description" text
);
CREATE TABLE "Products" (
  "product_id" varchar(36) PRIMARY KEY,
  "product_name" varchar(150),
  "product_description" text,
  "price" decimal(10, 2),
  "stock_quantity" int,
  "category_id" varchar(36)
);
CREATE TABLE "InventoryManagement" (
  "inventory_id" varchar(36) PRIMARY KEY,
  "product_id" varchar(36),
  "stock_in" int,
  "stock_out" int,
  "last_update" timestamp
);
CREATE TABLE "Suppliers" (
  "supplier_id" varchar(36) PRIMARY KEY,
  "supplier_name" varchar(100),
  "contact_person" varchar(100),
  "phone_number" varchar(20),
  "email" varchar(100),
  "address_id" varchar(36)
);
CREATE TABLE "PromoBanners" (
  "banner_id" varchar(36) PRIMARY KEY,
  "banner_text" varchar(255),
  "link" varchar(255),
  "display_from" date,
  "display_until" date
);
CREATE TABLE "OrderItems" (
  "order_item_id" varchar(36) PRIMARY KEY,
  "order_id" varchar(36),
  "product_id" varchar(36),
  "quantity" int,
  "unit_price" decimal(10, 2)
);
ALTER TABLE "WishlistItems" ADD FOREIGN KEY ("wishlist_id") REFERENCES "Wishlist" ("wishlist_id");
ALTER TABLE "Suppliers" ADD FOREIGN KEY ("address_id") REFERENCES "Addresses" ("address_id");
ALTER TABLE "Orders" ADD FOREIGN KEY ("billing_address_id") REFERENCES "Addresses" ("address_id");
ALTER TABLE "ShippingDetails" ADD FOREIGN KEY ("order_id") REFERENCES "Orders" ("order_id");
ALTER TABLE "Orders" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "ProductSuppliers" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "Reviews" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "Wishlist" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "ShippingDetails" ADD FOREIGN KEY ("shipping_method_id") REFERENCES "ShippingMethods" ("shipping_method_id");
ALTER TABLE "AffiliateSales" ADD FOREIGN KEY ("order_id") REFERENCES "Orders" ("order_id");
ALTER TABLE "Returns" ADD FOREIGN KEY ("order_id") REFERENCES "Orders" ("order_id");
ALTER TABLE "UserRoleAssignments" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "OrderItems" ADD FOREIGN KEY ("order_id") REFERENCES "Orders" ("order_id");
ALTER TABLE "Cart" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "ProductSuppliers" ADD FOREIGN KEY ("supplier_id") REFERENCES "Suppliers" ("supplier_id");
ALTER TABLE "WishlistItems" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "CartItems" ADD FOREIGN KEY ("cart_id") REFERENCES "Cart" ("cart_id");
ALTER TABLE "Products" ADD FOREIGN KEY ("category_id") REFERENCES "Categories" ("category_id");
ALTER TABLE "Discounts" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "Returns" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "CartItems" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "Reviews" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "OrderItems" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "AffiliateSales" ADD FOREIGN KEY ("affiliate_id") REFERENCES "Affiliates" ("affiliate_id");
ALTER TABLE "Orders" ADD FOREIGN KEY ("shipping_address_id") REFERENCES "Addresses" ("address_id");
ALTER TABLE "UserRoleAssignments" ADD FOREIGN KEY ("role_id") REFERENCES "UserRoles" ("role_id");
ALTER TABLE "Notifications" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "InventoryManagement" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "ProductImages" ADD FOREIGN KEY ("product_id") REFERENCES "Products" ("product_id");
ALTER TABLE "Feedback" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "Addresses" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "PaymentMethods" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "OrderTaxes" ADD FOREIGN KEY ("tax_id") REFERENCES "Taxes" ("tax_id");
ALTER TABLE "UserCoupons" ADD FOREIGN KEY ("coupon_id") REFERENCES "Coupons" ("coupon_id");
ALTER TABLE "UserCoupons" ADD FOREIGN KEY ("user_id") REFERENCES "Users" ("user_id");
ALTER TABLE "OrderTaxes" ADD FOREIGN KEY ("order_id") REFERENCES "Orders" ("order_id");
