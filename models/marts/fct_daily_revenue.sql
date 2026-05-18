WITH orders AS (
  SELECT
    order_id,
    customer_unique_id,
    purchased_at,
    item_count,
    subtotal,
    freight_total,
    order_total,
    is_cancelled
  FROM {{ ref('fct_orders') }}
  WHERE NOT is_cancelled
),

daily AS (
  SELECT
    DATE_TRUNC('day', purchased_at)::DATE  AS order_date,
    COUNT(order_id)                         AS order_count,
    COUNT(DISTINCT customer_unique_id)      AS unique_customers,
    SUM(item_count)                         AS total_items_sold,
    ROUND(SUM(order_total)::NUMERIC,   2)   AS gross_revenue,
    ROUND(SUM(subtotal)::NUMERIC,      2)   AS product_revenue,
    ROUND(SUM(freight_total)::NUMERIC, 2)   AS freight_revenue,
    ROUND(AVG(order_total)::NUMERIC,   2)   AS avg_order_value
  FROM orders
  GROUP BY 1
)

SELECT * FROM daily
ORDER BY order_date
