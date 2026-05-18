-- One row per real customer (customer_unique_id), with lifetime value metrics.
-- Uses DISTINCT ON to pick one address record per unique customer.
WITH customers AS (
  SELECT DISTINCT ON (customer_unique_id)
    customer_unique_id,
    city,
    state_code,
    postcode_prefix
  FROM {{ ref('stg_olist__customers') }}
  ORDER BY customer_unique_id
),

order_metrics AS (
  SELECT
    customer_unique_id,
    COUNT(order_id)                                   AS total_orders,
    SUM(order_total)                                  AS lifetime_value,
    AVG(order_total)                                  AS avg_order_value,
    MIN(purchased_at)                                 AS first_order_at,
    MAX(purchased_at)                                 AS latest_order_at,
    SUM(CASE WHEN is_delivered THEN 1 ELSE 0 END)     AS delivered_orders,
    SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END)     AS cancelled_orders
  FROM {{ ref('fct_orders') }}
  GROUP BY customer_unique_id
),

final AS (
  SELECT
    c.customer_unique_id,
    c.city,
    c.state_code,
    c.postcode_prefix,

    COALESCE(m.total_orders,      0)    AS total_orders,
    COALESCE(m.lifetime_value,    0)    AS lifetime_value,
    ROUND(m.avg_order_value::NUMERIC, 2) AS avg_order_value,
    m.first_order_at,
    m.latest_order_at,
    COALESCE(m.delivered_orders,  0)    AS delivered_orders,
    COALESCE(m.cancelled_orders,  0)    AS cancelled_orders,

    CASE WHEN COALESCE(m.total_orders, 0) > 1
      THEN TRUE ELSE FALSE
    END AS is_repeat_customer

  FROM customers c
  LEFT JOIN order_metrics m USING (customer_unique_id)
)

SELECT * FROM final
