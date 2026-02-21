```text
Você está no repositório aberto no VS Code (devcontainer) com Postgres já rodando.
Objetivo: importar o dataset Olist (9 CSVs em `datasets/`) para o Postgres, criando SOMENTE a base relacional no schema já existente `ecommerce`.

Mudança importante: criar as tabelas SEM FKs, carregar os CSVs, e só então aplicar as FKs (para evitar falhas durante a primeira carga). PKs podem existir desde o início.

Requisitos funcionais
1) Criar as tabelas relacionais “as-is” (espelhando os CSVs) no schema `ecommerce`:
   - ecommerce.customers
   - ecommerce.geolocation
   - ecommerce.orders
   - ecommerce.order_items
   - ecommerce.order_payments
   - ecommerce.order_reviews
   - ecommerce.products
   - ecommerce.sellers
   - ecommerce.product_category_name_translation

2) Importar todos os CSVs da pasta `datasets/` para essas tabelas.

3) Idempotência de ambiente dev: o comando deve poder ser executado novamente com resultado consistente.
   - Pode DROPAR e recriar as tabelas do Olist no schema `ecommerce` (somente as tabelas acima), usando CASCADE.
   - NÃO mexer em outros schemas/tabelas.

4) Conectividade:
   - Preferir `DATABASE_URL` se existir; caso contrário, usar variáveis padrão de Postgres (PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD).
   - O script deve falhar com mensagem clara se não conseguir conectar.

5) Performance:
   - Usar `psql` + `\copy ... CSV HEADER` (não inserir linha-a-linha).

6) Tipos e modelagem (base relacional, não estrela):
   - Manter nomes de colunas exatamente como nos CSVs (incluindo typos como `product_name_lenght`).
   - Usar tipos adequados: timestamps, numeric(10,2) para valores, int para contagens.
   - geolocation: NÃO tentar impor PK natural (há duplicatas). Pode criar `geolocation_id bigserial` como PK técnica OU deixar sem PK.

7) Chaves e índices (com FKs aplicadas APÓS a carga):
   - Criar PKs desde o início:
     * customers: PK(customer_id)
     * sellers: PK(seller_id)
     * products: PK(product_id)
     * orders: PK(order_id)
     * order_items: PK(order_id, order_item_id)
     * order_payments: PK(order_id, payment_sequential)
     * order_reviews: PK(review_id)
     * product_category_name_translation: PK(product_category_name)
   - Criar índices úteis para joins desde o início (ou após carga, tanto faz):
     * orders(customer_id)
     * order_items(order_id), order_items(product_id), order_items(seller_id)
     * order_payments(order_id)
     * order_reviews(order_id)
     * products(product_category_name)

8) Aplicação das FKs (DEPOIS da carga, em arquivo separado):
   - orders.customer_id -> customers.customer_id
   - order_items.order_id -> orders.order_id
   - order_items.product_id -> products.product_id
   - order_items.seller_id -> sellers.seller_id
   - order_payments.order_id -> orders.order_id
   - order_reviews.order_id -> orders.order_id
   Observação: se algum FK falhar por dados inconsistentes, o script deve abortar e imprimir qual constraint falhou (psql já faz isso; só garantir que o script não sufoque o erro).

9) Ordem de carga recomendada:
   - customers, sellers, products, product_category_name_translation, orders, order_items, order_payments, order_reviews, geolocation

Arquivos (criar no repo)
A) `scripts/olist/01_create_tables.sql`
   - Contém DDL para dropar (apenas as tabelas do Olist no schema ecommerce) e recriar com tipos, PKs e índices (SEM FKs).
B) `scripts/olist/02_load_data.sql`
   - Contém comandos `\copy` para carregar cada CSV para sua tabela.
   - Deve usar caminhos relativos `datasets/...`.
C) `scripts/olist/03_add_constraints.sql`
   - Contém apenas os `ALTER TABLE ... ADD CONSTRAINT ... FOREIGN KEY ...` listados acima.
D) `scripts/olist/load_olist.sh`
   - Script executável que:
     1) valida presença dos 9 CSVs (pelos nomes padrão do Kaggle):
        - olist_customers_dataset.csv
        - olist_geolocation_dataset.csv
        - olist_order_items_dataset.csv
        - olist_order_payments_dataset.csv
        - olist_order_reviews_dataset.csv
        - olist_orders_dataset.csv
        - olist_products_dataset.csv
        - olist_sellers_dataset.csv
        - product_category_name_translation.csv
     2) executa `psql` com:
        - 01_create_tables.sql
        - 02_load_data.sql
        - 03_add_constraints.sql
     3) ao final, roda um bloco de verificação imprimindo contagens:
        select 'orders' as table, count(*) from ecommerce.orders; (e assim por diante)
   - Se algum CSV não existir, abortar com erro claro mostrando quais faltam.
   - Se o `psql` não existir no container, instruir como instalar (mas não instalar automaticamente).

DDL mínimo esperado (colunas)
- customers:
  customer_id text, customer_unique_id text, customer_zip_code_prefix text, customer_city text, customer_state char(2)
- geolocation:
  geolocation_zip_code_prefix text, geolocation_lat double precision, geolocation_lng double precision, geolocation_city text, geolocation_state char(2)
- orders:
  order_id text, customer_id text, order_status text,
  order_purchase_timestamp timestamp, order_approved_at timestamp,
  order_delivered_carrier_date timestamp, order_delivered_customer_date timestamp,
  order_estimated_delivery_date timestamp
- order_items:
  order_id text, order_item_id int, product_id text, seller_id text,
  shipping_limit_date timestamp, price numeric(10,2), freight_value numeric(10,2)
- order_payments:
  order_id text, payment_sequential int, payment_type text, payment_installments int, payment_value numeric(10,2)
- order_reviews:
  review_id text, order_id text, review_score int,
  review_comment_title text, review_comment_message text,
  review_creation_date timestamp, review_answer_timestamp timestamp
- products:
  product_id text, product_category_name text,
  product_name_lenght int, product_description_lenght int, product_photos_qty int,
  product_weight_g int, product_length_cm int, product_height_cm int, product_width_cm int
- sellers:
  seller_id text, seller_zip_code_prefix text, seller_city text, seller_state char(2)
- product_category_name_translation:
  product_category_name text, product_category_name_english text

Aceitação
- Rodar `bash scripts/olist/load_olist.sh` termina sem erros.
- Todas as 9 tabelas existem em `ecommerce` e têm `count(*) > 0`.
- Joins básicos funcionam: orders↔customers, order_items↔orders, order_items↔products, order_items↔sellers, payments/reviews↔orders.
- As FKs aparecem em `\d ecommerce.orders` etc, após o `03_add_constraints.sql`.
```
