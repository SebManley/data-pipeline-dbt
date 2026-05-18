WITH source AS (
  SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
  FROM {{ source('olist', 'olist_order_items') }}
),

renamed AS (
  SELECT
    order_id,
    CAST(order_item_id  AS INTEGER)        AS order_item_id,
    product_id,
    seller_id,
    CAST(shipping_limit_date AS TIMESTAMP) AS shipping_limit_at,
    CAST(price          AS NUMERIC(10, 2)) AS price,
    CAST(freight_value  AS NUMERIC(10, 2)) AS freight_value,
    CAST(price AS NUMERIC(10, 2))
      + CAST(freight_value AS NUMERIC(10, 2)) AS line_total

  FROM source
  WHERE order_id IS NOT NULL
    AND order_item_id IS NOT NULL
)

SELECT * FROM renamed
