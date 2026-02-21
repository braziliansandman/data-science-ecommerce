# Perguntas de negócio

## 1. Receita e volume por mês
   
Pergunta 1: “Qual foi o GMV (soma de preço dos itens) e o número de pedidos por mês de compra?”

GMV significa **Gross Merchandise Value** (às vezes chamado de **Gross Merchandise Volume**). É o “valor bruto de mercadorias” transacionadas: a soma do valor dos itens vendidos em um período, antes de considerar coisas como devoluções, cancelamentos, descontos (dependendo de como você define), comissões, impostos e custos de frete.

No Olist, o GMV mais comum é definir como:

- GMV (sem frete) = soma de `order_items.price`

Risco: se você misturar `payments.payment_value` como se fosse GMV, você pode ter diferenças por causa de parcelamento, múltiplos registros de pagamento por pedido, e regras de negócio (descontos/valores finais).

Considere apenas pedidos com itens (exclua pedidos vazios, sem itens).

SQL (base relacional, com joins)

```sql
SELECT
  date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
  COUNT(DISTINCT o.order_id)                          AS orders,
  ROUND(SUM(oi.price)::numeric, 2)                    AS gmv_items
FROM ecommerce.orders o
JOIN ecommerce.order_items oi
  ON oi.order_id = o.order_id
GROUP BY 1
ORDER BY 1;
```

SQL (star schema)

```sql
SELECT
  make_date(d.year, d.month, 1)        AS purchase_month,
  COUNT(*)                              AS orders,
  ROUND(SUM(f.gmv_items)::numeric, 2)   AS gmv_items
FROM ecommerce.f_order f
JOIN ecommerce.d_date d
  ON d.date_key = f.purchase_date_key
GROUP BY 1
ORDER BY 1;
```

### Comentário didático (prós e cons)

No relacional, você precisa fazer join com `order_items` para calcular GMV e, por causa do grão “item do pedido”, precisa lembrar de `COUNT(DISTINCT o.order_id)` (senão você conta itens, não pedidos). Isso é bom para ensinar grão/normalização, mas aumenta a chance de erro (double count) e o SQL fica menos direto.

No star, `f_order` já está no grão correto (1 linha por pedido) e já tem a métrica `gmv_items`, então o SQL fica menor e mais “seguro” (COUNT(*) já é pedidos). O custo é que você depende do ETL: a definição de GMV está “embutida” na modelagem/transformação e precisa ser governada/atualizada quando regras mudarem.


## 2. Top categorias por receita e ticket médio
   
Pergunta 2: “Quais as 10 categorias com maior receita e qual o ticket médio por pedido em cada uma?”

SQL (base relacional, com joins)

```sql
SELECT
  COALESCE(t.product_category_name_english, p.product_category_name) AS category,
  ROUND(SUM(oi.price)::numeric, 2)                                   AS revenue_items,
  COUNT(DISTINCT oi.order_id)                                        AS orders_in_category,
  ROUND(
    (SUM(oi.price)::numeric / NULLIF(COUNT(DISTINCT oi.order_id), 0)),
    2
  )                                                                  AS avg_ticket_per_order_in_category
FROM ecommerce.order_items oi
JOIN ecommerce.products p
  ON p.product_id = oi.product_id
LEFT JOIN ecommerce.product_category_name_translation t
  ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY 1
ORDER BY revenue_items DESC
LIMIT 10;
```

SQL (star schema)

```sql
SELECT
  COALESCE(dp.product_category_name_english, dp.product_category_name) AS category,
  ROUND(SUM(foi.item_price)::numeric, 2)                               AS revenue_items,
  COUNT(DISTINCT foi.order_id)                                         AS orders_in_category,
  ROUND(
    (SUM(foi.item_price)::numeric / NULLIF(COUNT(DISTINCT foi.order_id), 0)),
    2
  )                                                                    AS avg_ticket_per_order_in_category
FROM ecommerce.f_order_item foi
JOIN ecommerce.d_product dp
  ON dp.product_key = foi.product_key
WHERE dp.product_category_name IS NOT NULL
GROUP BY 1
ORDER BY revenue_items DESC
LIMIT 10;
```

### Comentário didático (prós e cons)

No relacional, o aluno precisa “descobrir” onde mora a categoria (products) e ainda juntar a tradução (tabela de translation). Isso reforça entendimento do modelo normalizado e do caminho do dado, mas aumenta a chance de erro (esquecer a tradução, filtrar errado nulos, etc.) e deixa o SQL mais verboso.

No star, a categoria já está “embutida” em `d_product`, então você reduz joins e simplifica a leitura. O cuidado importante permanece nos dois: como o grão é item, o “ticket médio por pedido na categoria” exige `COUNT(DISTINCT order_id)`; se o aluno fizer `COUNT(*)`, ele calcula por item, não por pedido.

Nota para evitar confusão em sala: esse “ticket médio por pedido na categoria” é **receita da categoria / nº de pedidos que tiveram itens daquela categoria**. Como um pedido pode ter várias categorias, um mesmo pedido entra em múltiplas categorias — isso é esperado e tem implicação interpretativa.


## 3. Custo de frete e relação frete/valor por categoria

Pergunta 3: “Em quais categorias o frete pesa mais (frete/valor do item)?”

SQL (base relacional, com joins)

```sql
SELECT
  COALESCE(t.product_category_name_english, p.product_category_name) AS category,
  ROUND(SUM(oi.freight_value)::numeric, 2)                           AS freight_total,
  ROUND(SUM(oi.price)::numeric, 2)                                   AS items_total,
  ROUND(
    (SUM(oi.freight_value)::numeric / NULLIF(SUM(oi.price)::numeric, 0)),
    4
  )                                                                  AS freight_to_items_ratio
FROM ecommerce.order_items oi
JOIN ecommerce.products p
  ON p.product_id = oi.product_id
LEFT JOIN ecommerce.product_category_name_translation t
  ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY 1
HAVING SUM(oi.price) > 0
ORDER BY freight_to_items_ratio DESC
LIMIT 10;
```

SQL (star schema)

```sql
SELECT
  COALESCE(dp.product_category_name_english, dp.product_category_name) AS category,
  ROUND(SUM(foi.freight_value)::numeric, 2)                            AS freight_total,
  ROUND(SUM(foi.item_price)::numeric, 2)                               AS items_total,
  ROUND(
    (SUM(foi.freight_value)::numeric / NULLIF(SUM(foi.item_price)::numeric, 0)),
    4
  )                                                                    AS freight_to_items_ratio
FROM ecommerce.f_order_item foi
JOIN ecommerce.d_product dp
  ON dp.product_key = foi.product_key
WHERE dp.product_category_name IS NOT NULL
GROUP BY 1
HAVING SUM(foi.item_price) > 0
ORDER BY freight_to_items_ratio DESC
LIMIT 10;
```

### Comentário didático (prós e cons)

No relacional, além do join inevitável (itens → produtos → tradução), o aluno precisa lidar com mais “superfícies de erro”: coluna certa de frete, nulos, e a necessidade de proteger divisão por zero com `NULLIF`. Ele também tende a misturar `payments` aqui sem necessidade, o que bagunça o grão.

No star, o cálculo fica mais direto porque `f_order_item` já concentra as medidas no grão correto (item) e a categoria já está na dimensão. O trade-off é o mesmo: você está confiando que o ETL carregou corretamente `item_price` e `freight_value` e que a dimensão de produto está consistente com a tabela relacional.

Nota didática: “frete pesa mais” pode ser interpretado como (Σfrete / Σpreço) (o que usamos) ou como média de (frete/preço por item). São métricas diferentes; vale explicitar qual definição a pergunta usa.


## 4. SLA logístico: tempo de entrega e atraso por estado do vendedor

Pergunta 4: “Qual o tempo médio de entrega e a taxa de atraso (entrega após data estimada) por UF do seller?”

SQL (base relacional, com joins)

```sql
WITH order_seller AS (
  -- garante 1 linha por pedido por seller (um pedido pode ter múltiplos sellers)
  SELECT DISTINCT
    oi.order_id,
    oi.seller_id
  FROM ecommerce.order_items oi
),
order_metrics AS (
  SELECT
    o.order_id,
    o.order_delivered_customer_date::date   AS delivered_date,
    o.order_estimated_delivery_date::date   AS estimated_date,
    o.order_purchase_timestamp::date        AS purchase_date,
    CASE
      WHEN o.order_delivered_customer_date IS NULL THEN NULL
      ELSE (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date)
    END AS delivery_days,
    CASE
      WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL
      ELSE (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
    END AS late_flag
  FROM ecommerce.orders o
)
SELECT
  s.seller_state AS seller_uf,
  ROUND(AVG(om.delivery_days)::numeric, 2) AS avg_delivery_days,
  ROUND(AVG(CASE WHEN om.late_flag IS TRUE THEN 1.0
                 WHEN om.late_flag IS FALSE THEN 0.0
                 ELSE NULL END)::numeric, 4) AS late_rate,
  COUNT(*) AS order_seller_pairs
FROM order_seller os
JOIN ecommerce.sellers s
  ON s.seller_id = os.seller_id
JOIN order_metrics om
  ON om.order_id = os.order_id
WHERE s.seller_state IS NOT NULL
GROUP BY 1
ORDER BY late_rate DESC NULLS LAST, avg_delivery_days DESC NULLS LAST;
```

SQL (star schema)

```sql
WITH order_seller AS (
  -- 1 linha por pedido por seller, usando o fato de itens
  SELECT DISTINCT
    foi.order_id,
    foi.seller_key
  FROM ecommerce.f_order_item foi
)
SELECT
  ds.seller_state AS seller_uf,
  ROUND(AVG(fo.delivery_days)::numeric, 2) AS avg_delivery_days,
  ROUND(AVG(CASE WHEN fo.late_flag IS TRUE THEN 1.0
                 WHEN fo.late_flag IS FALSE THEN 0.0
                 ELSE NULL END)::numeric, 4) AS late_rate,
  COUNT(*) AS order_seller_pairs
FROM order_seller os
JOIN ecommerce.d_seller ds
  ON ds.seller_key = os.seller_key
JOIN ecommerce.f_order fo
  ON fo.order_id = os.order_id
WHERE ds.seller_state IS NOT NULL
GROUP BY 1
ORDER BY late_rate DESC NULLS LAST, avg_delivery_days DESC NULLS LAST;
```

### Comentário didático (prós e cons)

Aqui existe uma complexidade “real” de negócio: um pedido pode ter itens de mais de um seller. Então “por UF do seller” não é naturalmente “1 linha por pedido”; vira “pedido–seller”. No relacional, isso obriga você a deduplicar `order_items` para não multiplicar o mesmo pedido por item do seller (CTE `order_seller`). Se o aluno fizer `JOIN` direto `orders ↔ order_items ↔ sellers` e calcular médias, ele enviesará o resultado (pedidos com mais itens contam mais).

No star, `f_order` já traz `delivery_days` e `late_flag` prontos (menos chance de errar regra de data), mas você ainda precisa resolver o mesmo problema de granularidade (pedido–seller) usando `SELECT DISTINCT` em `f_order_item`. Ou seja: a estrela reduz a complexidade de “como medir atraso e entrega”, mas não elimina a necessidade de pensar no grão da pergunta.

Observação didática: se você quisesse uma estrela ainda mais “BI pura” para esse caso, poderia existir uma fato específica `f_order_seller` (1 linha por pedido–seller). Mas para primeira aula, a deduplicação explícita é uma boa oportunidade de ensinar granularidade e vieses de agregação.


## 5. Rotas mais relevantes (origem–destino)

Pergunta 5: “Quais rotas seller_UF → customer_UF geram mais receita e mais pedidos?”

SQL (base relacional, com joins)

```sql
SELECT
  s.seller_state   AS seller_uf,
  c.customer_state AS customer_uf,
  ROUND(SUM(oi.price)::numeric, 2)        AS revenue_items,
  COUNT(DISTINCT o.order_id)              AS orders
FROM ecommerce.orders o
JOIN ecommerce.customers c
  ON c.customer_id = o.customer_id
JOIN ecommerce.order_items oi
  ON oi.order_id = o.order_id
JOIN ecommerce.sellers s
  ON s.seller_id = oi.seller_id
WHERE s.seller_state IS NOT NULL
  AND c.customer_state IS NOT NULL
GROUP BY 1, 2
ORDER BY revenue_items DESC, orders DESC
LIMIT 20;
```

SQL (star schema)

```sql
SELECT
  ds.seller_state   AS seller_uf,
  dc.customer_state AS customer_uf,
  ROUND(SUM(foi.item_price)::numeric, 2)  AS revenue_items,
  COUNT(DISTINCT foi.order_id)            AS orders
FROM ecommerce.f_order_item foi
JOIN ecommerce.d_seller ds
  ON ds.seller_key = foi.seller_key
JOIN ecommerce.d_customer dc
  ON dc.customer_key = foi.customer_key
WHERE ds.seller_state IS NOT NULL
  AND dc.customer_state IS NOT NULL
GROUP BY 1, 2
ORDER BY revenue_items DESC, orders DESC
LIMIT 20;
```

### Comentário didático (prós e cons)

Nos dois modelos, o “caminho lógico” da pergunta é naturalmente item-level: receita por rota depende do seller do item e do cliente do pedido, então o grão base é `order_items`/`f_order_item`. O principal ponto didático é o uso de `COUNT(DISTINCT order_id)` para “pedidos”, porque a tabela está no grão de item; `COUNT(*)` contaria itens, não pedidos.

A diferença prática é que no relacional o aluno precisa descobrir e juntar quatro tabelas (orders → customers + order_items → sellers), enquanto no star o join fica mais curto e com chaves já resolvidas (`customer_key`, `seller_key`). O trade-off do star é governança: se alguma dimensão foi carregada com dados faltantes (ex.: UF nula, customer_key não mapeado), você pode “perder” linhas ou concentrar em NULL, e o aluno não vê imediatamente a causa porque ela está escondida no ETL.


## 6. Concentração de receita: vendedores que mais faturam

Pergunta 6: “Qual a participação (%) dos top 10 sellers no GMV total?”

SQL (base relacional, com joins)

```sql
WITH seller_gmv AS (
  SELECT
    oi.seller_id,
    SUM(oi.price) AS gmv_items
  FROM ecommerce.order_items oi
  GROUP BY 1
),
totals AS (
  SELECT SUM(gmv_items) AS gmv_total
  FROM seller_gmv
),
ranked AS (
  SELECT
    sg.seller_id,
    sg.gmv_items,
    t.gmv_total,
    (sg.gmv_items / NULLIF(t.gmv_total, 0)) AS share
  FROM seller_gmv sg
  CROSS JOIN totals t
)
SELECT
  r.seller_id,
  ROUND(r.gmv_items::numeric, 2)                 AS seller_gmv_items,
  ROUND((r.share * 100)::numeric, 4)             AS seller_share_pct
FROM ranked r
ORDER BY r.gmv_items DESC
LIMIT 10;
```

SQL (star schema)

```sql
WITH seller_gmv AS (
  SELECT
    foi.seller_key,
    SUM(foi.item_price) AS gmv_items
  FROM ecommerce.f_order_item foi
  GROUP BY 1
),
totals AS (
  SELECT SUM(gmv_items) AS gmv_total
  FROM seller_gmv
)
SELECT
  ds.seller_id,
  ROUND(sg.gmv_items::numeric, 2)                      AS seller_gmv_items,
  ROUND((sg.gmv_items / NULLIF(t.gmv_total, 0) * 100)::numeric, 4) AS seller_share_pct
FROM seller_gmv sg
CROSS JOIN totals t
JOIN ecommerce.d_seller ds
  ON ds.seller_key = sg.seller_key
ORDER BY sg.gmv_items DESC
LIMIT 10;
```

### Comentário didático (prós e cons)

Os dois SQLs são parecidos porque a métrica está no grão de item (GMV por seller depende de `seller_id` que vem do item). No relacional, você nem precisa de `orders` para isso — só `order_items` basta — e isso é um bom ponto didático: “não faça join por reflexo”. No star, a versão fica equivalente, com a vantagem de já ter `item_price` padronizado no fato e a dimensão do seller para recuperar o `seller_id`.

O risco didático principal em ambos é o aluno tentar usar `f_order.gmv_items` para “por seller” (não funciona, porque o pedido pode ter vários sellers) ou, no relacional, juntar `orders` sem necessidade e acabar duplicando linhas. Aqui a estrela não “salva” de pensar em grão: a escolha correta continua sendo o fato de itens.


## 7. Qualidade percebida vs logística

Pergunta 7: “Reviews (nota média) são piores quando há atraso? Compare nota média ‘on-time’ vs ‘late’.”

SQL (base relacional, com joins)

```sql
WITH reviews_latest AS (
  SELECT
    r.order_id,
    r.review_score,
    ROW_NUMBER() OVER (
      PARTITION BY r.order_id
      ORDER BY r.review_answer_timestamp DESC NULLS LAST,
               r.review_creation_date DESC NULLS LAST
    ) AS rn
  FROM ecommerce.order_reviews r
),
order_review AS (
  SELECT
    o.order_id,
    rl.review_score,
    CASE
      WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL
      ELSE (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date)
    END AS late_flag
  FROM ecommerce.orders o
  JOIN reviews_latest rl
    ON rl.order_id = o.order_id AND rl.rn = 1
)
SELECT
  CASE
    WHEN late_flag IS TRUE THEN 'late'
    WHEN late_flag IS FALSE THEN 'on_time'
    ELSE 'unknown'
  END AS delivery_status,
  COUNT(*)                                  AS reviewed_orders,
  ROUND(AVG(review_score)::numeric, 4)      AS avg_review_score
FROM order_review
GROUP BY 1
ORDER BY 1;
```

SQL (star schema)

```sql
SELECT
  CASE
    WHEN late_flag IS TRUE THEN 'late'
    WHEN late_flag IS FALSE THEN 'on_time'
    ELSE 'unknown'
  END AS delivery_status,
  COUNT(*)                               AS reviewed_orders,
  ROUND(AVG(review_score)::numeric, 4)   AS avg_review_score
FROM ecommerce.f_order
WHERE has_review = TRUE
GROUP BY 1
ORDER BY 1;
```

### Comentário didático (prós e cons)

No relacional, você precisa resolver duas coisas “chatas”, mas muito instrutivas: (i) escolher qual review usar quando há mais de uma por pedido (a CTE `reviews_latest` com `row_number()`), e (ii) calcular atraso com as datas do pedido. Isso ensina janela (window functions), tratamento de nulos e regras de negócio explícitas. O custo é verbosidade e maior chance de inconsistência se cada aluno escolher um critério diferente para “review mais recente” ou para atraso.

No star, essas decisões já foram empacotadas no ETL (`review_score`, `has_review`, `late_flag`), então o SQL fica curto e comparável entre alunos. O trade-off é didático: você perde a oportunidade de mostrar por que “review é 1 por pedido” não é garantido e como decisões de consolidação mudam resultados. Um bom gancho é pedir que eles expliquem (em texto) qual regra de consolidação está “escondida” na estrela e como isso afeta a interpretação.


## 8. Cancelamentos: onde e quando

Pergunta 8: “Qual a taxa de cancelamento por mês e por categoria?”

SQL (base relacional, com joins)

```sql id="7qek4c"
WITH order_category AS (
  -- 1 linha por pedido-categoria (pedido pode ter múltiplas categorias)
  SELECT DISTINCT
    o.order_id,
    date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
    o.order_status,
    COALESCE(t.product_category_name_english, p.product_category_name) AS category
  FROM ecommerce.orders o
  JOIN ecommerce.order_items oi
    ON oi.order_id = o.order_id
  JOIN ecommerce.products p
    ON p.product_id = oi.product_id
  LEFT JOIN ecommerce.product_category_name_translation t
    ON t.product_category_name = p.product_category_name
  WHERE p.product_category_name IS NOT NULL
)
SELECT
  purchase_month,
  category,
  COUNT(*) AS orders_in_category,
  SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
  ROUND(
    (SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END)::numeric
     / NULLIF(COUNT(*)::numeric, 0)),
    4
  ) AS cancel_rate
FROM order_category
GROUP BY 1, 2
ORDER BY 1, cancel_rate DESC, orders_in_category DESC;
```

SQL (star schema)

```sql id="g1u2x9"
WITH order_category AS (
  -- 1 linha por pedido-categoria usando fato de itens
  SELECT DISTINCT
    foi.order_id,
    make_date(d.year, d.month, 1) AS purchase_month,
    foi.order_status,
    COALESCE(dp.product_category_name_english, dp.product_category_name) AS category
  FROM ecommerce.f_order_item foi
  JOIN ecommerce.d_date d
    ON d.date_key = foi.purchase_date_key
  JOIN ecommerce.d_product dp
    ON dp.product_key = foi.product_key
  WHERE dp.product_category_name IS NOT NULL
)
SELECT
  purchase_month,
  category,
  COUNT(*) AS orders_in_category,
  SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
  ROUND(
    (SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END)::numeric
     / NULLIF(COUNT(*)::numeric, 0)),
    4
  ) AS cancel_rate
FROM order_category
GROUP BY 1, 2
ORDER BY 1, cancel_rate DESC, orders_in_category DESC;
```

### Comentário didático (prós e cons)

Aqui o “pulo do gato” não é o join em si; é o grão correto. “Cancelamento por mês e por categoria” não é naturalmente 1 linha por pedido: um pedido pode ter várias categorias. Se você agregar direto em `order_items`/`f_order_item` sem `DISTINCT order_id, category`, pedidos com mais itens (ou mais itens na mesma categoria) vão pesar mais e distorcer a taxa. Por isso as duas versões criam primeiro uma tabela derivada “pedido–categoria”.

No relacional, o aluno precisa navegar `orders → order_items → products → translation` e escolher um mês (aqui: mês de compra). No star, os joins são mais curtos (dimensões já “prontas”), mas a necessidade de deduplicação por pedido–categoria permanece. O trade-off é claro: estrela simplifica o caminho dos dados, mas não elimina a necessidade de raciocinar sobre granularidade e sobre a definição de “categoria do pedido”.



## 9. Mix de pagamento e valor médio

Pergunta 9: “Qual a distribuição por tipo de pagamento e o valor médio pago por pedido?”

SQL (base relacional, com joins)

```sql
WITH payments_per_order AS (
  SELECT
    op.order_id,
    SUM(op.payment_value) AS payment_total,
    CASE
      WHEN COUNT(*) = 0 THEN 'not_defined'
      WHEN COUNT(DISTINCT op.payment_type) = 1 THEN MIN(op.payment_type)
      ELSE 'mixed'
    END AS payment_type_resolved
  FROM ecommerce.order_payments op
  GROUP BY op.order_id
)
SELECT
  p.payment_type_resolved                           AS payment_type,
  COUNT(*)                                          AS orders,
  ROUND(AVG(p.payment_total)::numeric, 2)           AS avg_paid_per_order,
  ROUND(SUM(p.payment_total)::numeric, 2)           AS total_paid
FROM payments_per_order p
GROUP BY 1
ORDER BY orders DESC, total_paid DESC;
```

SQL (star schema)

```sql
SELECT
  dpt.payment_type                                  AS payment_type,
  COUNT(*)                                          AS orders,
  ROUND(AVG(fo.payment_total)::numeric, 2)          AS avg_paid_per_order,
  ROUND(SUM(fo.payment_total)::numeric, 2)          AS total_paid
FROM ecommerce.f_order fo
JOIN ecommerce.d_payment_type dpt
  ON dpt.payment_type_key = fo.primary_payment_type_key
GROUP BY 1
ORDER BY orders DESC, total_paid DESC;
```

### Comentário didático (prós e cons)

No relacional, pagamentos são um ponto clássico de “explosão” (múltiplas linhas por pedido). Para responder corretamente, você precisa primeiro agregar por `order_id` e resolver o “tipo de pagamento do pedido” (1 tipo, mixed, etc.). Sem esse pré-agrupamento, qualquer join com `orders` ou `order_items` tende a duplicar valores e inflar médias/somas. Isso é didaticamente valioso porque força o aluno a pensar em cardinalidade e em como transformar um fato “multi-linha” em uma métrica por pedido.

No star, essa decisão já está embutida no ETL (`payment_total` e `primary_payment_type_key` no grão de pedido), então o SQL fica curto e difícil de errar. O trade-off é que a regra de consolidação (“mixed”, “not_defined”) está “escondida” e precisa ser explicitada/documentada; senão, alunos podem achar que `payment_type` sempre vem “naturalmente” do dado, quando na verdade é uma convenção de modelagem.



## 10. Experiência do cliente por estado (NPS proxy)

Pergunta 10: “Quais UFs de clientes têm maior/menor nota média e qual a taxa de review (pedidos com review)?”

SQL (base relacional, com joins)

```sql
WITH reviews_latest AS (
  SELECT
    r.order_id,
    r.review_score,
    ROW_NUMBER() OVER (
      PARTITION BY r.order_id
      ORDER BY r.review_answer_timestamp DESC NULLS LAST,
               r.review_creation_date DESC NULLS LAST
    ) AS rn
  FROM ecommerce.order_reviews r
),
orders_with_review_flag AS (
  SELECT
    o.order_id,
    o.customer_id,
    CASE WHEN rl.order_id IS NULL THEN 0 ELSE 1 END AS has_review,
    rl.review_score
  FROM ecommerce.orders o
  LEFT JOIN reviews_latest rl
    ON rl.order_id = o.order_id AND rl.rn = 1
)
SELECT
  c.customer_state AS customer_uf,
  COUNT(*) AS orders,
  ROUND(AVG(has_review)::numeric, 4) AS review_rate,
  ROUND(AVG(review_score)::numeric, 4) AS avg_review_score_among_reviewed
FROM orders_with_review_flag ow
JOIN ecommerce.customers c
  ON c.customer_id = ow.customer_id
WHERE c.customer_state IS NOT NULL
GROUP BY 1
ORDER BY avg_review_score_among_reviewed DESC NULLS LAST;
```

SQL (star schema)

```sql
SELECT
  dc.customer_state AS customer_uf,
  COUNT(*) AS orders,
  ROUND(AVG(CASE WHEN fo.has_review THEN 1.0 ELSE 0.0 END)::numeric, 4) AS review_rate,
  ROUND(AVG(fo.review_score)::numeric, 4) AS avg_review_score_among_reviewed
FROM ecommerce.f_order fo
JOIN ecommerce.d_customer dc
  ON dc.customer_key = fo.customer_key
WHERE dc.customer_state IS NOT NULL
GROUP BY 1
ORDER BY avg_review_score_among_reviewed DESC NULLS LAST;
```

### Comentário didático (prós e cons)

No relacional, o aluno precisa (i) lidar com a multiplicidade de reviews por pedido (ou decidir uma regra) e (ii) construir explicitamente a “taxa de review” como um indicador binário por pedido e então tirar a média desse indicador. Isso é ótimo para ensinar janelas (`row_number()`), `LEFT JOIN` e a ideia de transformar um evento (existe review?) em métrica (proporção). O SQL fica mais longo e, se a regra de “review mais recente” variar, os resultados mudam.

No star, `has_review` e `review_score` já estão no grão de pedido, então a pergunta vira uma agregação direta por UF. A desvantagem é o mesmo padrão: as escolhas de consolidação (qual review usar) ficam fora da query e dependem do ETL; se houver bug ou mudança de regra, o SQL “correto” continua retornando números errados sem que o aluno perceba facilmente.

