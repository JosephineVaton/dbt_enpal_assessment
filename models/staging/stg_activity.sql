{{ config(materialized = "view", tags = ["staging"]) }}

-- Deduplicate on activity_id to keep the most recent record (if duplicates exist)
select distinct on (activity_id)
  activity_id::bigint       as activity_id,
  type                      as activity_type_key,
  assigned_to_user::bigint  as user_id,
  deal_id::bigint           as deal_id,
  done::boolean             as is_done,
  due_to::timestamp         as due_to
from {{ source('pipedrive', 'activity') }}
order by activity_id, due_to desc
