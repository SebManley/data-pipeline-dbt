{{
  config(
    materialized = 'incremental',
    unique_key   = 'order_id',
    on_schema_change = 'fail'
  )
}}

WITH orders AS (
  SELECT
    order_id,
    customer_id,
    order_status,
    is_delivered,
    is_cancelled,
    purchased_at,
    approved_at,
    shipped_at,
    delivered_at,
    estimated_delivery_at
  FROM {{ ref('stg_olist__orders') }}
  {% if is_incremental() %}
    -- Only process orders newer than the latest already loaded
    WHERE purchased_at > (SELECT MAX(purchased_at) FROM {{ this }})
  {% endif %}
),

order_items AS (
  SELECT
    order_id,
    COUNT(*)             AS item_count,
    SUM(price)           AS subtotal,
    SUM(freight_value)   AS freight_total,
    SUM(line_total)      AS order_total
  FROM {{ ref('stg_olist__order_items') }}
  GROUP BY order_id
),

customers AS (
  SELECT
    customer_id,
    customer_unique_id,
    city    AS customer_city,
    state_code AS customer_state
  FROM {{ ref('stg_olist__customers') }}
),

final AS (
  SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,

    o.order_status,
    o.is_delivered,
    o.is_cancelled,

    o.purchased_at,
    o.approved_at,
    o.shipped_at,
    o.delivered_at,
    o.estimated_delivery_at,

    -- Delivery performance
    CASE
      WHEN o.delivered_at IS NOT NULL
       AND o.estimated_delivery_at IS NOT NULL
      THEN o.delivered_at <= o.estimated_delivery_at
    END AS delivered_on_time,

    EXTRACT(
      DAY FROM (o.delivered_at - o.purchased_at)
    )::INTEGER AS days_to_deliver,

    -- Order financials
    COALESCE(oi.item_count,    0)    AS item_count,
    COALESCE(oi.subtotal,      0)    AS subtotal,
    COALESCE(oi.freight_total, 0)    AS freight_total,
    COALESCE(oi.order_total,   0)    AS order_total

  FROM orders o
  LEFT JOIN customers  c  USING (customer_id)
  LEFT JOIN order_items oi USING (order_id)
)

SELECT * FROM final
