WITH items_agg AS (
    SELECT
        oi.order_id,
        COUNT(*)::INT AS item_count,
        COALESCE(SUM(oi.price), 0)::NUMERIC(12,2) AS gmv_items,
        COALESCE(SUM(oi.freight_value), 0)::NUMERIC(12,2) AS freight_total
    FROM ecommerce.order_items oi
    GROUP BY oi.order_id
),
payments_base AS (
    SELECT
        op.order_id,
        COALESCE(SUM(op.payment_value), 0)::NUMERIC(12,2) AS payment_total,
        COUNT(DISTINCT op.payment_type)::INT AS payment_type_distinct_count,
        MIN(op.payment_type) FILTER (WHERE op.payment_type IS NOT NULL) AS single_payment_type
    FROM ecommerce.order_payments op
    GROUP BY op.order_id
),
payments_agg AS (
    SELECT
        o.order_id,
        COALESCE(pb.payment_total, 0)::NUMERIC(12,2) AS payment_total,
        CASE
            WHEN pb.order_id IS NULL THEN 'not_defined'
            WHEN pb.payment_type_distinct_count = 1 THEN pb.single_payment_type
            WHEN pb.payment_type_distinct_count > 1 THEN 'mixed'
            ELSE 'not_defined'
        END AS primary_payment_type
    FROM ecommerce.orders o
    LEFT JOIN payments_base pb
        ON pb.order_id = o.order_id
),
reviews_latest AS (
    SELECT
        ranked.order_id,
        ranked.review_score,
        TRUE AS has_review
    FROM (
        SELECT
            r.order_id,
            r.review_score,
            ROW_NUMBER() OVER (
                PARTITION BY r.order_id
                ORDER BY r.review_answer_timestamp DESC NULLS LAST, r.review_creation_date DESC NULLS LAST
            ) AS rn
        FROM ecommerce.order_reviews r
    ) ranked
    WHERE ranked.rn = 1
)
INSERT INTO ecommerce.f_order (
    order_id,
    customer_key,
    purchase_date_key,
    delivered_date_key,
    estimated_delivery_date_key,
    order_status,
    item_count,
    gmv_items,
    freight_total,
    payment_total,
    primary_payment_type_key,
    has_review,
    review_score,
    delivery_days,
    late_flag
)
SELECT
    o.order_id,
    dc.customer_key,
    dd_purchase.date_key AS purchase_date_key,
    dd_delivered.date_key AS delivered_date_key,
    dd_estimated.date_key AS estimated_delivery_date_key,
    o.order_status,
    COALESCE(ia.item_count, 0) AS item_count,
    COALESCE(ia.gmv_items, 0)::NUMERIC(12,2) AS gmv_items,
    COALESCE(ia.freight_total, 0)::NUMERIC(12,2) AS freight_total,
    COALESCE(pa.payment_total, 0)::NUMERIC(12,2) AS payment_total,
    dpt.payment_type_key AS primary_payment_type_key,
    COALESCE(rl.has_review, FALSE) AS has_review,
    rl.review_score::SMALLINT AS review_score,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
            THEN (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)
        ELSE NULL
    END AS delivery_days,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
            THEN (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
        ELSE NULL
    END AS late_flag
FROM ecommerce.orders o
JOIN ecommerce.d_customer dc
    ON dc.customer_id = o.customer_id
JOIN ecommerce.d_date dd_purchase
    ON dd_purchase.date = o.order_purchase_timestamp::date
LEFT JOIN ecommerce.d_date dd_delivered
    ON dd_delivered.date = o.order_delivered_customer_date::date
LEFT JOIN ecommerce.d_date dd_estimated
    ON dd_estimated.date = o.order_estimated_delivery_date::date
LEFT JOIN items_agg ia
    ON ia.order_id = o.order_id
LEFT JOIN payments_agg pa
    ON pa.order_id = o.order_id
JOIN ecommerce.d_payment_type dpt
    ON dpt.payment_type = pa.primary_payment_type
LEFT JOIN reviews_latest rl
    ON rl.order_id = o.order_id;

INSERT INTO ecommerce.f_order_item (
    order_id,
    order_item_id,
    customer_key,
    seller_key,
    product_key,
    purchase_date_key,
    shipping_limit_date_key,
    order_status,
    late_flag,
    item_price,
    freight_value,
    qty
)
SELECT
    oi.order_id,
    oi.order_item_id,
    dc.customer_key,
    ds.seller_key,
    dp.product_key,
    dd_purchase.date_key AS purchase_date_key,
    dd_shipping.date_key AS shipping_limit_date_key,
    o.order_status,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
            THEN (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
        ELSE NULL
    END AS late_flag,
    oi.price::NUMERIC(12,2) AS item_price,
    oi.freight_value::NUMERIC(12,2) AS freight_value,
    1 AS qty
FROM ecommerce.order_items oi
JOIN ecommerce.orders o
    ON o.order_id = oi.order_id
JOIN ecommerce.d_customer dc
    ON dc.customer_id = o.customer_id
JOIN ecommerce.d_seller ds
    ON ds.seller_id = oi.seller_id
JOIN ecommerce.d_product dp
    ON dp.product_id = oi.product_id
JOIN ecommerce.d_date dd_purchase
    ON dd_purchase.date = o.order_purchase_timestamp::date
LEFT JOIN ecommerce.d_date dd_shipping
    ON dd_shipping.date = oi.shipping_limit_date::date;
