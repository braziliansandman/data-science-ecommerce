ALTER TABLE ecommerce.orders
    ADD CONSTRAINT fk_orders_customer_id
    FOREIGN KEY (customer_id)
    REFERENCES ecommerce.customers (customer_id);

ALTER TABLE ecommerce.order_items
    ADD CONSTRAINT fk_order_items_order_id
    FOREIGN KEY (order_id)
    REFERENCES ecommerce.orders (order_id);

ALTER TABLE ecommerce.order_items
    ADD CONSTRAINT fk_order_items_product_id
    FOREIGN KEY (product_id)
    REFERENCES ecommerce.products (product_id);

ALTER TABLE ecommerce.order_items
    ADD CONSTRAINT fk_order_items_seller_id
    FOREIGN KEY (seller_id)
    REFERENCES ecommerce.sellers (seller_id);

ALTER TABLE ecommerce.order_payments
    ADD CONSTRAINT fk_order_payments_order_id
    FOREIGN KEY (order_id)
    REFERENCES ecommerce.orders (order_id);

ALTER TABLE ecommerce.order_reviews
    ADD CONSTRAINT fk_order_reviews_order_id
    FOREIGN KEY (order_id)
    REFERENCES ecommerce.orders (order_id);