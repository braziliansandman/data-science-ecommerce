Você está no repositório aberto no VS Code (devcontainer) com Postgres já rodando.
A base relacional do Olist já foi carregada no schema `ecommerce` com as tabelas:
customers, geolocation, orders, order_items, order_payments, order_reviews, products, sellers, product_category_name_translation.

Objetivo: criar uma camada estrela (star schema) MÍNIMA no mesmo schema `ecommerce`, com:
Dimensões: d_date, d_customer, d_seller, d_product, d_payment_type
Fatos: f_order (1 linha por order_id) e f_order_item (1 linha por order_id+order_item_id)

Regras de negócio obrigatórias (para manter métricas consistentes)
1) f_order é no grão de pedido (order_id único).
   - gmv_items = soma(order_items.price) por order_id
   - freight_total = soma(order_items.freight_value) por order_id
   - payment_total = soma(order_payments.payment_value) por order_id
2) primary_payment_type (por order_id):
   - se NÃO houver pagamento -> 'not_defined'
   - se houver exatamente 1 tipo distinto -> esse tipo
   - se houver >1 tipo distinto -> 'mixed'
   (d_payment_type deve conter 'mixed' e 'not_defined' mesmo que não existam no CSV)
3) review_score (por order_id):
   - selecionar a review “mais recente” por order_id usando:
     order by review_answer_timestamp desc nulls last, review_creation_date desc nulls last
   - has_review = true se existir review, senão false
4) late_flag (por order_id):
   - somente quando delivered_customer_date e estimated_delivery_date existirem
   - late_flag = (delivered_customer_date::date > estimated_delivery_date::date)
   - caso contrário, late_flag = NULL
5) delivery_days (por order_id):
   - somente quando delivered_customer_date existir
   - delivery_days = (delivered_customer_date::date - order_purchase_timestamp::date)
   - caso contrário, NULL
6) d_date deve cobrir o intervalo completo de datas relevantes:
   - min_date = min(orders.order_purchase_timestamp::date)
   - max_date = max(GREATEST(
        coalesce(order_purchase_timestamp::date, '1900-01-01'::date),
        coalesce(order_approved_at::date, '1900-01-01'::date),
        coalesce(order_delivered_carrier_date::date, '1900-01-01'::date),
        coalesce(order_delivered_customer_date::date, '1900-01-01'::date),
        coalesce(order_estimated_delivery_date::date, '1900-01-01'::date)
     ))
   - popular d_date com generate_series(min_date, max_date, interval '1 day')
   - date_key int no formato YYYYMMDD

Decisão de modelagem (mantenha simples e didático)
- Dimensões com surrogate key (serial/bigserial), mas guardando o ID natural como coluna UNIQUE:
  d_customer: customer_id (natural key) + customer_unique_id como atributo
  d_seller: seller_id (natural key)
  d_product: product_id (natural key)
  d_payment_type: payment_type (natural key)
- d_date usa date_key como PK (sem surrogate).

Tabelas e colunas (criar exatamente assim)
A) ecommerce.d_date
- date_key int primary key
- date date unique not null
- year smallint, month smallint, quarter smallint
- month_name text, day_name text
- week_of_year smallint
- day_of_month smallint
- day_of_week smallint  (1=Mon .. 7=Sun, ISO)
- is_weekend boolean

B) ecommerce.d_customer
- customer_key bigserial primary key
- customer_id text not null unique
- customer_unique_id text
- customer_zip_code_prefix text
- customer_city text
- customer_state char(2)

C) ecommerce.d_seller
- seller_key bigserial primary key
- seller_id text not null unique
- seller_zip_code_prefix text
- seller_city text
- seller_state char(2)

D) ecommerce.d_product
- product_key bigserial primary key
- product_id text not null unique
- product_category_name text
- product_category_name_english text
- product_name_lenght int
- product_description_lenght int
- product_photos_qty int
- product_weight_g int
- product_length_cm int
- product_height_cm int
- product_width_cm int

E) ecommerce.d_payment_type
- payment_type_key smallserial primary key
- payment_type text not null unique

F) ecommerce.f_order  (1 linha por order_id)
- order_id text primary key
- customer_key bigint not null references ecommerce.d_customer(customer_key)
- purchase_date_key int not null references ecommerce.d_date(date_key)
- delivered_date_key int null references ecommerce.d_date(date_key)
- estimated_delivery_date_key int null references ecommerce.d_date(date_key)
- order_status text
- item_count int
- gmv_items numeric(12,2)
- freight_total numeric(12,2)
- payment_total numeric(12,2)
- primary_payment_type_key int not null references ecommerce.d_payment_type(payment_type_key)
- has_review boolean not null
- review_score smallint null
- delivery_days int null
- late_flag boolean null

G) ecommerce.f_order_item  (1 linha por order_id + order_item_id)
- order_id text not null
- order_item_id int not null
- customer_key bigint not null references ecommerce.d_customer(customer_key)
- seller_key bigint not null references ecommerce.d_seller(seller_key)
- product_key bigint not null references ecommerce.d_product(product_key)
- purchase_date_key int not null references ecommerce.d_date(date_key)
- shipping_limit_date_key int null references ecommerce.d_date(date_key)
- order_status text
- late_flag boolean null
- item_price numeric(12,2)
- freight_value numeric(12,2)
- qty int not null default 1
PRIMARY KEY (order_id, order_item_id)

Índices mínimos (criar ao final)
- f_order(customer_key), f_order(purchase_date_key), f_order(primary_payment_type_key)
- f_order_item(purchase_date_key), f_order_item(product_key), f_order_item(seller_key), f_order_item(customer_key)
- d_product(product_category_name), d_product(product_category_name_english)

Idempotência
- NÃO dropar tabelas relacionais.
- Dropar e recriar SOMENTE as tabelas estrela (d_* e f_*) listadas acima.

Arquivos a criar no repo
1) `scripts/olist/star/10_drop_create_star.sql`
   - DROP TABLE IF EXISTS ecommerce.f_order_item, ecommerce.f_order, ecommerce.d_payment_type, ecommerce.d_product, ecommerce.d_seller, ecommerce.d_customer, ecommerce.d_date CASCADE;
   - CREATE TABLEs conforme especificação (sem inserts).

2) `scripts/olist/star/11_build_dimensions.sql`
   - Popular d_date (com DO $$ para buscar min/max e inserir generate_series).
   - Popular d_customer a partir de ecommerce.customers.
   - Popular d_seller a partir de ecommerce.sellers.
   - Popular d_product a partir de ecommerce.products LEFT JOIN ecommerce.product_category_name_translation.
   - Popular d_payment_type com DISTINCT payment_type de ecommerce.order_payments + inserir 'mixed' e 'not_defined' se faltarem.

3) `scripts/olist/star/12_build_facts.sql`
   - Construir staging CTEs agregadas:
     a) items_agg por order_id (sum price, sum freight, count)
     b) payments_agg por order_id (sum payment_value, count distinct payment_type, resolved primary_payment_type)
     c) reviews_latest por order_id (row_number() e pick 1)
   - Inserir em f_order juntando:
     orders o
     -> d_customer via o.customer_id
     -> d_date via datas (purchase/delivered/estimated)
     -> items_agg/payments_agg/reviews_latest
     -> primary_payment_type_key via d_payment_type(payment_type)
     -> late_flag e delivery_days conforme regras
   - Inserir em f_order_item juntando:
     order_items oi
     -> orders o (para customer_id, status e datas)
     -> d_customer/d_seller/d_product
     -> d_date para purchase_date_key e shipping_limit_date_key
     -> late_flag calculado no nível do pedido (mesma regra) e copiado para a linha do item

4) `scripts/olist/star/13_indexes_analyze_checks.sql`
   - Criar índices mínimos.
   - Rodar ANALYZE nas novas tabelas.
   - Rodar checks e imprimir resultados:
     * contagens: f_order = count(*) de ecommerce.orders; f_order_item = count(*) de ecommerce.order_items
     * chaves nulas: contar linhas em fatos com customer_key/seller_key/product_key/date_key NULL (deve ser 0, exceto delivered/estimated keys)
     * sanity: sum(gmv_items) vs sum(order_items.price) (deve bater)
     * payment_total vs sum(order_payments.payment_value) (deve bater)
   - Se algum check não bater, imprimir NOTICE com o delta, mas NÃO quebrar o script (use DO $$ BEGIN ... EXCEPTION ... END $$ onde fizer sentido).

5) `scripts/olist/star/build_star.sh`
   - Script executável que roda, em ordem:
     - 10_drop_create_star.sql
     - 11_build_dimensions.sql
     - 12_build_facts.sql
     - 13_indexes_analyze_checks.sql
   - Deve aceitar conexão via DATABASE_URL ou variáveis PG*
   - Deve abortar se falhar criação/carga (exceto os checks finais que são só aviso).

Aceitação
- `bash scripts/olist/star/build_star.sh` termina com exit code 0.
- As tabelas d_* e f_* existem no schema ecommerce.
- f_order tem exatamente a mesma contagem de linhas que ecommerce.orders.
- f_order_item tem exatamente a mesma contagem de linhas que ecommerce.order_items.
- Os checks de soma (GMV e payment_total) batem com deltas 0.00.

Implemente exatamente isso, com SQL limpo e comentários curtos só onde houver decisão não óbvia.
