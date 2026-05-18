WITH source AS (
  SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
  FROM {{ source('olist', 'olist_customers') }}
),

renamed AS (
  SELECT
    customer_id,
    customer_unique_id,
    CAST(customer_zip_code_prefix AS TEXT)  AS postcode_prefix,
    INITCAP(customer_city)                  AS city,
    customer_state                          AS state_code
  FROM source
  WHERE customer_id IS NOT NULL
)

SELECT * FROM renamed
