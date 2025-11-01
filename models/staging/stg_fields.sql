{{ config(materialized = "view", tags = ["staging"]) }}

select
  id::bigint              as field_id,
  field_key               as field_key,
  name                    as field_name,
  field_value_options     as field_value_options
from {{ source('pipedrive', 'fields') }}
