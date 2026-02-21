DO $$
DECLARE
    v_min_date DATE;
    v_max_date DATE;
BEGIN
    SELECT MIN(o.order_purchase_timestamp::date)
      INTO v_min_date
      FROM ecommerce.orders o;

    SELECT MAX(
        GREATEST(
            COALESCE(o.order_purchase_timestamp::date, DATE '1900-01-01'),
            COALESCE(o.order_approved_at::date, DATE '1900-01-01'),
            COALESCE(o.order_delivered_carrier_date::date, DATE '1900-01-01'),
            COALESCE(o.order_delivered_customer_date::date, DATE '1900-01-01'),
            COALESCE(o.order_estimated_delivery_date::date, DATE '1900-01-01')
        )
    )
      INTO v_max_date
      FROM ecommerce.orders o;

    IF v_min_date IS NULL OR v_max_date IS NULL THEN
        RAISE EXCEPTION 'Não foi possível determinar min_date/max_date em ecommerce.orders';
    END IF;

    INSERT INTO ecommerce.d_date (
        date_key,
        date,
        year,
        month,
        quarter,
        month_name,
        day_name,
        week_of_year,
        day_of_month,
        day_of_week,
        is_weekend
    )
    SELECT
        TO_CHAR(d::date, 'YYYYMMDD')::INT AS date_key,
        d::date AS date,
        EXTRACT(YEAR FROM d)::SMALLINT AS year,
        EXTRACT(MONTH FROM d)::SMALLINT AS month,
        EXTRACT(QUARTER FROM d)::SMALLINT AS quarter,
        TRIM(TO_CHAR(d, 'Month')) AS month_name,
        TRIM(TO_CHAR(d, 'Day')) AS day_name,
        EXTRACT(WEEK FROM d)::SMALLINT AS week_of_year,
        EXTRACT(DAY FROM d)::SMALLINT AS day_of_month,
        EXTRACT(ISODOW FROM d)::SMALLINT AS day_of_week,
        (EXTRACT(ISODOW FROM d) IN (6, 7)) AS is_weekend
    FROM generate_series(v_min_date, v_max_date, INTERVAL '1 day') AS gs(d);
END $$;

INSERT INTO ecommerce.d_customer (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state
FROM ecommerce.customers c;

INSERT INTO ecommerce.d_seller (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state
FROM ecommerce.sellers s;

INSERT INTO ecommerce.d_product (
    product_id,
    product_category_name,
    product_category_name_english,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    p.product_id,
    p.product_category_name,
    pct.product_category_name_english,
    p.product_name_lenght,
    p.product_description_lenght,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM ecommerce.products p
LEFT JOIN ecommerce.product_category_name_translation pct
    ON pct.product_category_name = p.product_category_name;

INSERT INTO ecommerce.d_payment_type (payment_type)
SELECT payment_type
FROM (
    SELECT DISTINCT op.payment_type
    FROM ecommerce.order_payments op
    WHERE op.payment_type IS NOT NULL

    UNION

    SELECT 'mixed'

    UNION

    SELECT 'not_defined'
) src;
