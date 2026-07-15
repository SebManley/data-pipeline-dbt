WITH source AS (
  SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
  FROM {{ source('olist', 'olist_orders') }}
),

renamed AS (
  SELECT
    order_id,
    customer_id,
    order_status,
    CAST(order_purchase_timestamp      AS TIMESTAMP) AS purchased_at,
    CAST(order_approved_at             AS TIMESTAMP) AS approved_at,
    CAST(order_delivered_carrier_date  AS TIMESTAMP) AS shipped_at,
    CAST(order_delivered_customer_date AS TIMESTAMP) AS delivered_at,
    CAST(order_estimated_delivery_date AS TIMESTAMP) AS estimated_delivery_at,

    CASE WHEN order_status = 'delivered'
      THEN TRUE ELSE FALSE
    END AS is_delivered,

    CASE WHEN order_status IN ('canceled', 'unavailable')
      THEN TRUE ELSE FALSE
    END AS is_cancelled

  FROM source
  WHERE order_id IS NOT NULL
)

SELECT * FROM renamed
