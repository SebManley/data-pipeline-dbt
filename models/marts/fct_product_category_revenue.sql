WITH order_items AS (
  SELECT
    order_id,
    product_id,
    line_total
  FROM {{ ref('stg_olist__order_items') }}
),

orders AS (
  SELECT order_id
  FROM {{ ref('stg_olist__orders') }}
  WHERE NOT is_cancelled
    AND purchased_at < '{{ var("max_complete_order_date") }}'
),

products AS (
  SELECT
    product_id,
    product_category
  FROM {{ ref('stg_olist__products') }}
),

joined AS (
  SELECT
    COALESCE(p.product_category, 'Unknown') AS product_category,
    oi.order_id,
    oi.line_total
  FROM order_items oi
  INNER JOIN orders   o USING (order_id)
  LEFT JOIN  products p USING (product_id)
),

final AS (
  SELECT
    product_category,
    COUNT(DISTINCT order_id)            AS order_count,
    COUNT(*)                            AS item_count,
    ROUND(SUM(line_total)::NUMERIC, 2)  AS revenue
  FROM joined
  GROUP BY product_category
)

SELECT * FROM final
