CREATE SCHEMA IF NOT EXISTS ecommerce;

DROP TABLE IF EXISTS ecommerce.order_items CASCADE;
DROP TABLE IF EXISTS ecommerce.order_payments CASCADE;
DROP TABLE IF EXISTS ecommerce.order_reviews CASCADE;
DROP TABLE IF EXISTS ecommerce.orders CASCADE;
DROP TABLE IF EXISTS ecommerce.customers CASCADE;
DROP TABLE IF EXISTS ecommerce.products CASCADE;
DROP TABLE IF EXISTS ecommerce.sellers CASCADE;
DROP TABLE IF EXISTS ecommerce.product_category_name_translation CASCADE;
DROP TABLE IF EXISTS ecommerce.geolocation CASCADE;

CREATE TABLE ecommerce.customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state CHAR(2)
);

CREATE TABLE ecommerce.sellers (
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state CHAR(2)
);

CREATE TABLE ecommerce.products (
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

CREATE TABLE ecommerce.product_category_name_translation (
    product_category_name TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE ecommerce.orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT,
    order_status TEXT,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE ecommerce.order_items (
    order_id TEXT,
    order_item_id INT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE ecommerce.order_payments (
    order_id TEXT,
    payment_sequential INT,
    payment_type TEXT,
    payment_installments INT,
    payment_value NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

CREATE TABLE ecommerce.order_reviews (
    review_id TEXT PRIMARY KEY,
    order_id TEXT,
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE ecommerce.geolocation (
    geolocation_id BIGSERIAL PRIMARY KEY,
    geolocation_zip_code_prefix TEXT,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city TEXT,
    geolocation_state CHAR(2)
);

CREATE INDEX idx_orders_customer_id ON ecommerce.orders (customer_id);
CREATE INDEX idx_order_items_order_id ON ecommerce.order_items (order_id);
CREATE INDEX idx_order_items_product_id ON ecommerce.order_items (product_id);
CREATE INDEX idx_order_items_seller_id ON ecommerce.order_items (seller_id);
CREATE INDEX idx_order_payments_order_id ON ecommerce.order_payments (order_id);
CREATE INDEX idx_order_reviews_order_id ON ecommerce.order_reviews (order_id);
CREATE INDEX idx_products_category_name ON ecommerce.products (product_category_name);