{{ config(materialized = "view", tags = ["staging"]) }}

select
  activity_id::bigint       as activity_id,
  type                      as activity_type_key,
  assigned_to_user::bigint  as user_id,
  deal_id::bigint           as deal_id,
  done::boolean             as is_done,
  due_to::timestamp         as due_to
from {{ source('pipedrive', 'activity') }}
