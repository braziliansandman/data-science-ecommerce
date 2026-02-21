\copy ecommerce.customers (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state) FROM 'datasets/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true);

\copy ecommerce.sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state) FROM 'datasets/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true);

\copy ecommerce.products (product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm) FROM 'datasets/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true);

\copy ecommerce.product_category_name_translation (product_category_name, product_category_name_english) FROM 'datasets/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true);

\copy ecommerce.orders (order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date) FROM 'datasets/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true);

\copy ecommerce.order_items (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value) FROM 'datasets/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true);

\copy ecommerce.order_payments (order_id, payment_sequential, payment_type, payment_installments, payment_value) FROM 'datasets/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true);

CREATE TEMP TABLE stg_order_reviews (
	review_id TEXT,
	order_id TEXT,
	review_score INT,
	review_comment_title TEXT,
	review_comment_message TEXT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP
);

\copy stg_order_reviews (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp) FROM 'datasets/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true);

INSERT INTO ecommerce.order_reviews (review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp)
SELECT DISTINCT ON (review_id)
	review_id,
	order_id,
	review_score,
	review_comment_title,
	review_comment_message,
	review_creation_date,
	review_answer_timestamp
FROM stg_order_reviews
ORDER BY review_id, review_answer_timestamp DESC NULLS LAST, review_creation_date DESC NULLS LAST;

\copy ecommerce.geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state) FROM 'datasets/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true);