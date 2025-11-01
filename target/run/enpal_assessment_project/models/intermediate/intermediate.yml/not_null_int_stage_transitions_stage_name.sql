
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select stage_name
from "postgres"."public_pipedrive_analytics"."int_stage_transitions"
where stage_name is null



  
  
      
    ) dbt_internal_test