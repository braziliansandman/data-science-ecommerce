CREATE INDEX idx_f_order_customer_key ON ecommerce.f_order (customer_key);
CREATE INDEX idx_f_order_purchase_date_key ON ecommerce.f_order (purchase_date_key);
CREATE INDEX idx_f_order_primary_payment_type_key ON ecommerce.f_order (primary_payment_type_key);

CREATE INDEX idx_f_order_item_purchase_date_key ON ecommerce.f_order_item (purchase_date_key);
CREATE INDEX idx_f_order_item_product_key ON ecommerce.f_order_item (product_key);
CREATE INDEX idx_f_order_item_seller_key ON ecommerce.f_order_item (seller_key);
CREATE INDEX idx_f_order_item_customer_key ON ecommerce.f_order_item (customer_key);

CREATE INDEX idx_d_product_category_name ON ecommerce.d_product (product_category_name);
CREATE INDEX idx_d_product_category_name_english ON ecommerce.d_product (product_category_name_english);

ANALYZE ecommerce.d_date;
ANALYZE ecommerce.d_customer;
ANALYZE ecommerce.d_seller;
ANALYZE ecommerce.d_product;
ANALYZE ecommerce.d_payment_type;
ANALYZE ecommerce.f_order;
ANALYZE ecommerce.f_order_item;

SELECT 'orders_vs_f_order' AS check_name,
       (SELECT COUNT(*) FROM ecommerce.orders) AS source_count,
       (SELECT COUNT(*) FROM ecommerce.f_order) AS target_count,
       ((SELECT COUNT(*) FROM ecommerce.f_order) - (SELECT COUNT(*) FROM ecommerce.orders)) AS delta;

SELECT 'order_items_vs_f_order_item' AS check_name,
       (SELECT COUNT(*) FROM ecommerce.order_items) AS source_count,
       (SELECT COUNT(*) FROM ecommerce.f_order_item) AS target_count,
       ((SELECT COUNT(*) FROM ecommerce.f_order_item) - (SELECT COUNT(*) FROM ecommerce.order_items)) AS delta;

SELECT 'f_order_null_keys' AS check_name,
       COUNT(*) FILTER (WHERE customer_key IS NULL) AS null_customer_key,
       COUNT(*) FILTER (WHERE purchase_date_key IS NULL) AS null_purchase_date_key,
       COUNT(*) FILTER (WHERE primary_payment_type_key IS NULL) AS null_primary_payment_type_key
FROM ecommerce.f_order;

SELECT 'f_order_item_null_keys' AS check_name,
       COUNT(*) FILTER (WHERE customer_key IS NULL) AS null_customer_key,
       COUNT(*) FILTER (WHERE seller_key IS NULL) AS null_seller_key,
       COUNT(*) FILTER (WHERE product_key IS NULL) AS null_product_key,
       COUNT(*) FILTER (WHERE purchase_date_key IS NULL) AS null_purchase_date_key
FROM ecommerce.f_order_item;

SELECT 'gmv_compare' AS check_name,
       COALESCE((SELECT SUM(gmv_items) FROM ecommerce.f_order), 0)::NUMERIC(14,2) AS f_order_gmv,
       COALESCE((SELECT SUM(price) FROM ecommerce.order_items), 0)::NUMERIC(14,2) AS source_gmv,
       (COALESCE((SELECT SUM(gmv_items) FROM ecommerce.f_order), 0) - COALESCE((SELECT SUM(price) FROM ecommerce.order_items), 0))::NUMERIC(14,2) AS delta;

SELECT 'payment_compare' AS check_name,
       COALESCE((SELECT SUM(payment_total) FROM ecommerce.f_order), 0)::NUMERIC(14,2) AS f_order_payment_total,
       COALESCE((SELECT SUM(payment_value) FROM ecommerce.order_payments), 0)::NUMERIC(14,2) AS source_payment_total,
       (COALESCE((SELECT SUM(payment_total) FROM ecommerce.f_order), 0) - COALESCE((SELECT SUM(payment_value) FROM ecommerce.order_payments), 0))::NUMERIC(14,2) AS delta;

DO $$
DECLARE
    v_orders_count BIGINT;
    v_f_order_count BIGINT;
    v_order_items_count BIGINT;
    v_f_order_item_count BIGINT;
    v_gmv_delta NUMERIC(14,2);
    v_payment_delta NUMERIC(14,2);
BEGIN
    SELECT COUNT(*) INTO v_orders_count FROM ecommerce.orders;
    SELECT COUNT(*) INTO v_f_order_count FROM ecommerce.f_order;
    SELECT COUNT(*) INTO v_order_items_count FROM ecommerce.order_items;
    SELECT COUNT(*) INTO v_f_order_item_count FROM ecommerce.f_order_item;

    SELECT (COALESCE((SELECT SUM(gmv_items) FROM ecommerce.f_order), 0) - COALESCE((SELECT SUM(price) FROM ecommerce.order_items), 0))::NUMERIC(14,2)
      INTO v_gmv_delta;

    SELECT (COALESCE((SELECT SUM(payment_total) FROM ecommerce.f_order), 0) - COALESCE((SELECT SUM(payment_value) FROM ecommerce.order_payments), 0))::NUMERIC(14,2)
      INTO v_payment_delta;

    IF v_f_order_count <> v_orders_count THEN
        RAISE NOTICE 'Check mismatch: f_order (%), orders (%), delta (%)', v_f_order_count, v_orders_count, (v_f_order_count - v_orders_count);
    END IF;

    IF v_f_order_item_count <> v_order_items_count THEN
        RAISE NOTICE 'Check mismatch: f_order_item (%), order_items (%), delta (%)', v_f_order_item_count, v_order_items_count, (v_f_order_item_count - v_order_items_count);
    END IF;

    IF v_gmv_delta <> 0 THEN
        RAISE NOTICE 'Check mismatch: GMV delta = %', v_gmv_delta;
    END IF;

    IF v_payment_delta <> 0 THEN
        RAISE NOTICE 'Check mismatch: payment_total delta = %', v_payment_delta;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Checks concluídos com aviso: %', SQLERRM;
END $$;
