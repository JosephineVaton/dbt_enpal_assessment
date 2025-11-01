{{ config(materialized = "view", tags = ["staging"]) }}

select
  deal_id::bigint           as deal_id,
  change_time::timestamp    as change_time,
  changed_field_key         as changed_field_key,
  new_value                 as new_value
from {{ source('pipedrive', 'deal_changes') }}
