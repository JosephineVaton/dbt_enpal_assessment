{{ config(materialized = "view", tags = ["staging"]) }}

select
  stage_id::int           as stage_id,
  stage_name              as stage_name
from {{ source('pipedrive', 'stages') }}
