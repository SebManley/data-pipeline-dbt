WITH source AS (
  SELECT
    product_id,
    product_category_name
  FROM {{ source('olist', 'olist_products') }}
),

translation AS (
  SELECT
    product_category_name,
    product_category_name_english
  FROM {{ source('olist', 'olist_category_translation') }}
),

renamed AS (
  SELECT
    s.product_id,
    INITCAP(
      REPLACE(COALESCE(t.product_category_name_english, s.product_category_name, 'unknown'), '_', ' ')
    ) AS product_category
  FROM source s
  LEFT JOIN translation t USING (product_category_name)
  WHERE s.product_id IS NOT NULL
)

SELECT * FROM renamed
