/* ============================================================
   PIPEDRIVE CRM — EXPLORATORY DATA ANALYSIS (EDA)
   Author: Soeur Ruth
   Date: 2025-10-31
   Target: PostgreSQL (local, Docker)
   ============================================================ */

-- Optional: ensure we read from the public schema by default
-- SET search_path TO public;

/* ============================================================
   1) INVENTORY — TABLES & VOLUMES
   ============================================================ */

-- 1.1 Tables présentes dans le schéma public
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema='public'
ORDER BY 1,2;

-- 1.2 Volumes (nombre de lignes par table source)
SELECT 'activity' AS t, COUNT(*) FROM public.activity
UNION ALL SELECT 'activity_types', COUNT(*) FROM public.activity_types
UNION ALL SELECT 'deal_changes', COUNT(*) FROM public.deal_changes
UNION ALL SELECT 'fields', COUNT(*) FROM public.fields
UNION ALL SELECT 'stages', COUNT(*) FROM public.stages
UNION ALL SELECT 'users', COUNT(*) FROM public.users
ORDER BY 1;


/* ============================================================
   2) COMPLETENESS — NULLS & CHAMPS CLÉS
   ============================================================ */

-- 2.1 activity : colonnes critiques nulles ?
SELECT
  COUNT(*) AS n,
  COUNT(*) FILTER (WHERE activity_id IS NULL) AS null_activity_id,
  COUNT(*) FILTER (WHERE deal_id IS NULL)     AS null_deal_id,
  COUNT(*) FILTER (WHERE due_to IS NULL)      AS null_due_to
FROM public.activity;

-- 2.2 users : emails manquants / doublons
SELECT
  COUNT(*) AS n_users,
  COUNT(*) FILTER (WHERE email IS NULL OR TRIM(email)='') AS null_email,
  COUNT(DISTINCT email) AS distinct_email
FROM public.users;

-- 2.3 deal_changes : complétude des champs clés
SELECT
  COUNT(*) AS n_changes,
  COUNT(*) FILTER (WHERE deal_id IS NULL) AS null_deal_id,
  COUNT(*) FILTER (WHERE change_time IS NULL) AS null_change_time,
  COUNT(*) FILTER (WHERE changed_field_key IS NULL) AS null_changed_key,
  COUNT(*) FILTER (WHERE new_value IS NULL) AS null_new_value
FROM public.deal_changes;

-- 2.4 stages : id/nom non vides ?
SELECT
  COUNT(*) AS n_stages,
  COUNT(*) FILTER (WHERE stage_id IS NULL) AS null_stage_id,
  COUNT(*) FILTER (WHERE stage_name IS NULL OR TRIM(stage_name)='') AS null_stage_name
FROM public.stages;


/* ============================================================
   3) REFERENTIAL INTEGRITY — LIENS & COUVERTURE
   ============================================================ */

-- 3.1 deal_changes.stage_id existe dans stages ?
WITH stage_moves AS (
  SELECT deal_id, change_time, new_value::int AS stage_id
  FROM public.deal_changes
  WHERE changed_field_key='stage_id' AND new_value ~ '^[0-9]+$'
)
SELECT COUNT(*) AS n_moves, 
       COUNT(*) FILTER (WHERE s.stage_id IS NULL) AS n_stage_not_found
FROM stage_moves m
LEFT JOIN public.stages s ON s.stage_id = m.stage_id;

-- 3.2 deals présents dans activity vs deal_changes (diagnostic de couverture)
SELECT COUNT(DISTINCT a.deal_id) AS deals_in_activity,
       COUNT(DISTINCT dc.deal_id) AS deals_in_deal_changes
FROM public.activity a
LEFT JOIN public.deal_changes dc ON dc.deal_id = a.deal_id;

-- 3.3 users sans email (potentiellement orphelins pour rapports par sales rep)
SELECT id, name
FROM public.users
WHERE email IS NULL OR TRIM(email)='';


/* ============================================================
   4) TEMPORAL VALIDATION — BORNES, FUTUR, DOUBLONS
   ============================================================ */

-- 4.1 Bornes temporelles sur deal_changes
SELECT MIN(change_time) AS min_change, MAX(change_time) AS max_change
FROM public.deal_changes;

-- 4.2 Événements futurs (au-delà de "now()")
SELECT COUNT(*) AS future_changes
FROM public.deal_changes
WHERE change_time > NOW();

-- 4.3 Multiples changements au même instant pour le même deal
SELECT deal_id, change_time, COUNT(*) AS n
FROM public.deal_changes
GROUP BY 1,2
HAVING COUNT(*) > 1
ORDER BY n DESC, change_time DESC
LIMIT 20;


/* ============================================================
   5) DISTRIBUTIONS RAPIDES — CLÉS & ACTIVITÉS
   ============================================================ */

-- 5.1 Répartition des changed_field_key
SELECT changed_field_key, COUNT(*) AS n
FROM public.deal_changes
GROUP BY 1
ORDER BY n DESC;

-- 5.2 Stage IDs rencontrés (via deal_changes)
SELECT new_value, COUNT(*) AS n
FROM public.deal_changes
WHERE changed_field_key='stage_id'
GROUP BY 1
ORDER BY n DESC;

-- 5.3 Activités "done" vs "non done"
SELECT done, COUNT(*) AS n
FROM public.activity
GROUP BY 1
ORDER BY 2 DESC;


/* ============================================================
   6) FUNNEL DIAGNOSTICS — TRANSITIONS DE STAGE
   ============================================================ */

-- 6.1 Tous les mouvements de stage (base)
WITH stage_moves AS (
  SELECT deal_id, change_time, new_value::int AS stage_id
  FROM public.deal_changes
  WHERE changed_field_key='stage_id' AND new_value ~ '^[0-9]+$'
)
SELECT COUNT(*) AS n_moves,
       COUNT(DISTINCT deal_id) AS n_deals_moved
FROM stage_moves;

-- 6.2 1er stage observé par deal
WITH stage_moves AS (
  SELECT deal_id, change_time, new_value::int AS stage_id
  FROM public.deal_changes
  WHERE changed_field_key='stage_id' AND new_value ~ '^[0-9]+$'
),
first_move AS (
  SELECT deal_id, MIN(change_time) AS first_change
  FROM stage_moves
  GROUP BY 1
)
SELECT m.deal_id, m.stage_id, m.change_time
FROM stage_moves m
JOIN first_move f ON f.deal_id=m.deal_id AND f.first_change=m.change_time
ORDER BY m.change_time
LIMIT 50;

-- 6.3 Allers-retours (downgrades) : stage courant < stage précédent
WITH ordered AS (
  SELECT deal_id,
         change_time,
         new_value::int AS stage_id,
         LAG(new_value::int) OVER (PARTITION BY deal_id ORDER BY change_time) AS prev_stage
  FROM public.deal_changes
  WHERE changed_field_key='stage_id' AND new_value ~ '^[0-9]+$'
)
SELECT COUNT(*) AS n_downgrades
FROM ordered
WHERE prev_stage IS NOT NULL AND stage_id < prev_stage;

-- 6.4 Couverture mensuelle brute (base du futur modèle)
WITH stage_moves AS (
  SELECT deal_id, change_time, new_value::int AS stage_id
  FROM public.deal_changes
  WHERE changed_field_key='stage_id' AND new_value ~ '^[0-9]+$'
)
SELECT date_trunc('month', change_time) AS month,
       stage_id,
       COUNT(DISTINCT deal_id) AS deals_count
FROM stage_moves
GROUP BY 1,2
ORDER BY 1,2;


/* ============================================================
   7) INDEXES (OPTIONNEL) — POUR ACCÉLÉRER LES ANALYSES
   ============================================================ */

CREATE INDEX IF NOT EXISTS idx_deal_changes_deal_time
  ON public.deal_changes (deal_id, change_time);

CREATE INDEX IF NOT EXISTS idx_deal_changes_stage
  ON public.deal_changes (changed_field_key, new_value);


/* ============================================================
   8) PRIMARY KEYS — UNIQUENESS & STRUCTURAL VALIDATION
   ============================================================ */

-- 8.1 activity: each activity must have a unique ID
SELECT
  COUNT(activity_id) AS n_total,
  COUNT(DISTINCT activity_id) AS n_unique,
  COUNT(activity_id) - COUNT(DISTINCT activity_id) AS n_duplicates
FROM public.activity;

-- 8.2 deal_changes: uniqueness of the (deal_id, change_time) pair
SELECT
  COUNT(*) AS n_total,
  COUNT(DISTINCT (deal_id, change_time)) AS n_unique_composite,
  COUNT(*) - COUNT(DISTINCT (deal_id, change_time)) AS n_duplicates
FROM public.deal_changes;

-- 8.3 stages: each sales stage must be unique
SELECT
  COUNT(stage_id) AS n_total,
  COUNT(DISTINCT stage_id) AS n_unique,
  COUNT(stage_id) - COUNT(DISTINCT stage_id) AS n_duplicates
FROM public.stages;

-- 8.4 users: each user must have a unique ID
SELECT
  COUNT(id) AS n_total,
  COUNT(DISTINCT id) AS n_unique,
  COUNT(id) - COUNT(DISTINCT id) AS n_duplicates
FROM public.users;

-- 8.5 activity_types: each activity type must be unique
SELECT
  COUNT(id) AS n_total,
  COUNT(DISTINCT id) AS n_unique,
  COUNT(id) - COUNT(DISTINCT id) AS n_duplicates
FROM public.activity_types;

-- 8.6 fields: each custom field must be unique (fixed: field_key)
SELECT
  COUNT(field_key) AS n_total,
  COUNT(DISTINCT field_key) AS n_unique,
  COUNT(field_key) - COUNT(DISTINCT field_key) AS n_duplicates
FROM public.fields;

-- 8.7 activity duplicates detail (diagnostic)
SELECT activity_id, COUNT(*) AS count
FROM public.activity
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY count DESC, activity_id;
