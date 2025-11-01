{{ config(materialized = "view", tags = ["staging"]) }}

select
  id::bigint              as user_id,
  name                    as user_name,
  email                   as email,
  modified::timestamp     as modified_time
from {{ source('pipedrive', 'users') }}
