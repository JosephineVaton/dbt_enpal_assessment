{{ config(
    materialized = "view",
    tags = ["intermediate"]
) }}

select
  a.deal_id,
  a.due_to::timestamp as activity_date,
  at.activity_type_name,
  at.activity_type_key,
  a.is_done as is_completed
from {{ ref('stg_activity') }} a
left join {{ ref('stg_activity_types') }} at
  on a.activity_type_key = at.activity_type_key
where a.deal_id is not null