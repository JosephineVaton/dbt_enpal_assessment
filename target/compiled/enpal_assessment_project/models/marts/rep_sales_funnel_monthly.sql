

with stage_transitions as (
    select
        date_trunc('month', change_time) as month,
        stage_name as kpi_name,
        stage_name as funnel_step,
        count(distinct deal_id) as deals_count
    from "postgres"."public_pipedrive_analytics"."int_stage_transitions"
    group by 1, 2, 3
),

activity_events as (
    select
        date_trunc('month', activity_date) as month,
        activity_type_name as kpi_name,
        activity_type_name as funnel_step,
        count(distinct deal_id) as deals_count
    from "postgres"."public_pipedrive_analytics"."int_activity_events"
    where is_completed = true
    group by 1, 2, 3
)

select *
from stage_transitions
union all
select *
from activity_events