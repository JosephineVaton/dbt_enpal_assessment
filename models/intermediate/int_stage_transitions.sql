{{ config(
    materialized = "view",
    tags = ["intermediate"]
) }}

select
  dc.deal_id,
  dc.change_time::timestamp as change_time,
  dc.new_value::int as stage_id,
  s.stage_name
from {{ ref('stg_deal_changes') }} dc
left join {{ ref('stg_stages') }} s
  on dc.new_value::int = s.stage_id
where dc.changed_field_key = 'stage_id'
