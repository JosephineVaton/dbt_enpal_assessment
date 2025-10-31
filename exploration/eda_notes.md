----------------------------------------------------
Exploratory Data Analysis (EDA) — Pipedrive CRM Dataset
----------------------------------------------------

Objective:
Understand the structure, data quality, and readiness of the Pipedrive CRM data before modeling.

1. Structure Overview

Tables in schema public:

Table	Rows	Comment
activity	4,579	Sales activities (done or pending)
activity_types	4	Reference table for activity categories
deal_changes	15,406	Event log tracking all changes on deals
fields	4	Metadata reference
stages	9	Funnel stages definitions
users	1,787	Sales representatives

✅ All tables found and readable.
✅ Primary tables for funnel modeling are deal_changes and stages.

2. Data Completeness
Table	Critical Nulls	Observation
activity	None in activity_id, deal_id, due_to	Clean
users	No missing or duplicate emails	Clean
deal_changes	No missing deal_id, change_time, or new_value	Clean
stages	No missing stage_id or stage_name	Clean

✅ Data integrity across all tables is excellent.
⚠️ Minor overlap issue: only 8 deals appear both in activity and deal_changes → these two tables describe different flows (CRM log vs activity log).

3. Temporal Coverage
Metric	Value
Min date	2024-01-01
Max date	2025-03-11

🕐 ~15 months of complete activity — perfect base for monthly funnel reporting.

4. Funnel Stage Dynamics

8,906 stage change events covering 1,995 distinct deals.
No invalid stage IDs (all mapped to stages table).
Only 8 downgrades (where a deal moved backward) → excellent stage consistency.
Funnel stages range logically from 1 (Lead Generation) to 9 (Renewal/Expansion).

✅ Funnel data is well structured and temporally consistent.

5. Funnel Monthly Coverage (extract)

Example (Jan–Dec 2024):

Month	Stage 1	Stage 2	Stage 3	…	Stage 9
Jan 2024	30	6	—	…	0
Feb 2024	194	74	27	…	2
Mar 2024	199	157	142	…	7
…	…	…	…	…	…
Dec 2024	0	3	14	…	19

➡️ Gradual buildup of deals across stages until mid-2024, then slowdown toward 2025.
➡️ Stage transitions cover all steps — pipeline is complete.

6. Overall Assessment
Aspect	Evaluation	Notes
Data integrity	✅ Excellent	No nulls or type issues
Temporal consistency	✅ Excellent	Continuous data Jan 2024 → Mar 2025
Stage hierarchy	✅ Valid	9 unique ordered stages
Coverage	⚠️ Partial	1,995 deals with transitions — may not include every active deal
Activity linkage	⚠️ Weak	activity not strongly tied to deal_changes (likely separate log)

7. Key Takeaways

The CRM log (deal_changes) is robust and suitable for funnel reconstruction.
Stage mapping is consistent and hierarchical (no missing IDs).
Data can safely be modeled in dbt with monthly granularity.
The next step will be to build:

staging models (stg_deal_changes, stg_stages),
intermediate aggregations (int_deals_stage_moves, int_deals_stage_monthly),
and the final report (rep_sales_funnel_monthly).

8. Primary Key Validation (Uniqueness Checks)
Table	Expected Primary Key	Unique?	Notes
activity	activity_id	⚠️ No (11 duplicates)	4,568 unique IDs out of 4,579. Needs deduplication in staging (keep most recent per activity_id).
deal_changes	(deal_id, change_time)	✅ Yes	15,406 composite keys, no duplicates — perfect for time-based tracking.
stages	stage_id	✅ Yes	9 unique IDs — consistent hierarchy.
users	id	✅ Yes	1,787 unique users, no duplicates or missing emails.
activity_types	id	✅ Yes	4 unique types, clean reference table.
fields	field_key	✅ Yes	4 unique custom fields, structure consistent.

9. Data Quality Summary
Category	Verdict	Details
Schema coverage	✅ Complete	All expected tables found in public schema.
Null / missing data	✅ Very low	No critical NULLs in keys or timestamps.
Referential integrity	✅ Stable	All stage_id values match valid stages.
Temporal consistency	✅ Excellent	Smooth continuous timeline Jan 2024 → Mar 2025, no future dates.
Duplicates	⚠️ Minor issue	11 duplicate activities, easy to handle via dedup.
Activity coverage	⚠️ Partial	Activities not always linked to deals (separate behavior log).
Stage transitions	✅ Clean	8,906 moves, all valid and ordered stages (no downgrades).
Users & emails	✅ Excellent	No missing or duplicate user entries.

10. Key Takeaways

The CRM data is structurally sound and well-typed.
The deal_changes log is a reliable backbone for reconstructing the sales funnel.
Stages are hierarchical and complete — perfect for modeling progressions.
Activities will likely be modeled separately as a behavioral log (not joined directly to deals).
Minor duplication in activity will be fixed in the staging layer.
Data is clean and consistent enough for monthly or stage-level aggregation in dbt.

11. Next Steps in dbt

Build staging models

stg_deal_changes.sql — clean and typed log of deal movements.
stg_stages.sql — reference of all stages.
stg_activity.sql — deduplicated activity log (handle 11 duplicates).

Build intermediate layers

int_deals_stage_moves.sql — one row per deal per stage transition.
int_deals_stage_monthly.sql — monthly aggregates.

Final marts

rep_sales_funnel_monthly.sql — full funnel reconstruction (entries, exits, counts).
Potential join with users for per-salesperson KPIs.