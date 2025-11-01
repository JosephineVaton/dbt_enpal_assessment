{{ config(
    materialized = "view",
    tags = ["staging"]
) }}

select
  id::bigint       as activity_type_id,
  name             as activity_type_name,
  type             as activity_type_key,
  active::boolean  as active_flag
from {{ source('pipedrive', 'activity_types') }}