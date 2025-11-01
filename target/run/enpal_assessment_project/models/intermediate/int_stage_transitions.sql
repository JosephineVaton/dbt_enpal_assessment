
  create view "postgres"."public_pipedrive_analytics"."int_stage_transitions__dbt_tmp"
    
    
  as (
    

select
  dc.deal_id,
  dc.change_time::timestamp as change_time,
  dc.new_value::int as stage_id,
  s.stage_name
from "postgres"."public_pipedrive_analytics"."stg_deal_changes" dc
left join "postgres"."public_pipedrive_analytics"."stg_stages" s
  on dc.new_value::int = s.stage_id
where dc.changed_field_key = 'stage_id'
  );