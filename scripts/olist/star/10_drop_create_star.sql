DROP TABLE IF EXISTS ecommerce.f_order_item, ecommerce.f_order, ecommerce.d_payment_type, ecommerce.d_product, ecommerce.d_seller, ecommerce.d_customer, ecommerce.d_date CASCADE;

CREATE TABLE ecommerce.d_date (
    date_key INT PRIMARY KEY,
    date DATE UNIQUE NOT NULL,
    year SMALLINT,
    month SMALLINT,
    quarter SMALLINT,
    month_name TEXT,
    day_name TEXT,
    week_of_year SMALLINT,
    day_of_month SMALLINT,
    day_of_week SMALLINT,
    is_weekend BOOLEAN
);

CREATE TABLE ecommerce.d_customer (
    customer_key BIGSERIAL PRIMARY KEY,
    customer_id TEXT NOT NULL UNIQUE,
    customer_unique_id TEXT,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state CHAR(2)
);

CREATE TABLE ecommerce.d_seller (
    seller_key BIGSERIAL PRIMARY KEY,
    seller_id TEXT NOT NULL UNIQUE,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state CHAR(2)
);

CREATE TABLE ecommerce.d_product (
    product_key BIGSERIAL PRIMARY KEY,
    product_id TEXT NOT NULL UNIQUE,
    product_category_name TEXT,
    product_category_name_english TEXT,
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

CREATE TABLE ecommerce.d_payment_type (
    payment_type_key SMALLSERIAL PRIMARY KEY,
    payment_type TEXT NOT NULL UNIQUE
);

CREATE TABLE ecommerce.f_order (
    order_id TEXT PRIMARY KEY,
    customer_key BIGINT NOT NULL REFERENCES ecommerce.d_customer(customer_key),
    purchase_date_key INT NOT NULL REFERENCES ecommerce.d_date(date_key),
    delivered_date_key INT NULL REFERENCES ecommerce.d_date(date_key),
    estimated_delivery_date_key INT NULL REFERENCES ecommerce.d_date(date_key),
    order_status TEXT,
    item_count INT,
    gmv_items NUMERIC(12,2),
    freight_total NUMERIC(12,2),
    payment_total NUMERIC(12,2),
    primary_payment_type_key INT NOT NULL REFERENCES ecommerce.d_payment_type(payment_type_key),
    has_review BOOLEAN NOT NULL,
    review_score SMALLINT NULL,
    delivery_days INT NULL,
    late_flag BOOLEAN NULL
);

CREATE TABLE ecommerce.f_order_item (
    order_id TEXT NOT NULL,
    order_item_id INT NOT NULL,
    customer_key BIGINT NOT NULL REFERENCES ecommerce.d_customer(customer_key),
    seller_key BIGINT NOT NULL REFERENCES ecommerce.d_seller(seller_key),
    product_key BIGINT NOT NULL REFERENCES ecommerce.d_product(product_key),
    purchase_date_key INT NOT NULL REFERENCES ecommerce.d_date(date_key),
    shipping_limit_date_key INT NULL REFERENCES ecommerce.d_date(date_key),
    order_status TEXT,
    late_flag BOOLEAN NULL,
    item_price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    qty INT NOT NULL DEFAULT 1,
    PRIMARY KEY (order_id, order_item_id)
);
