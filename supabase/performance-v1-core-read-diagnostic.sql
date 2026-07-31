-- Performance V1: read-only core database diagnostic.
-- Safe to run in the Supabase SQL editor: this file does not change application data
-- or database objects. EXPLAIN is intentionally used without ANALYZE, so the sample
-- business queries are planned but not executed.

-- 1. Table activity, stale-row pressure and total disk footprint.
select
  s.relname as table_name,
  s.n_live_tup as estimated_live_rows,
  s.n_dead_tup as estimated_dead_rows,
  s.seq_scan,
  s.seq_tup_read,
  s.idx_scan,
  s.idx_tup_fetch,
  s.n_tup_ins,
  s.n_tup_upd,
  s.n_tup_del,
  s.last_analyze,
  s.last_autoanalyze,
  pg_size_pretty(pg_total_relation_size(s.relid)) as total_size,
  pg_size_pretty(pg_relation_size(s.relid)) as table_size,
  pg_size_pretty(pg_indexes_size(s.relid)) as indexes_size
from pg_stat_user_tables s
where s.schemaname = 'public'
  and s.relname = any (array[
    'societies', 'people', 'person_guardians', 'society_members',
    'sections', 'member_sections', 'section_role_assignments',
    'society_events', 'event_participants',
    'wardrobe_items', 'wardrobe_assignments', 'wardrobe_assignment_items',
    'financial_obligations', 'financial_payments'
  ])
order by pg_total_relation_size(s.relid) desc, s.relname;

-- 2. Index inventory and observed use since statistics were last reset.
select
  ui.relname as table_name,
  ui.indexrelname as index_name,
  ui.idx_scan,
  ui.idx_tup_read,
  ui.idx_tup_fetch,
  pg_size_pretty(pg_relation_size(ui.indexrelid)) as index_size,
  i.indisunique as is_unique,
  i.indisprimary as is_primary,
  i.indisvalid as is_valid,
  i.indisready as is_ready,
  pg_get_indexdef(ui.indexrelid) as definition
from pg_stat_user_indexes ui
join pg_index i on i.indexrelid = ui.indexrelid
where ui.schemaname = 'public'
  and ui.relname = any (array[
    'societies', 'people', 'person_guardians', 'society_members',
    'sections', 'member_sections', 'section_role_assignments',
    'society_events', 'event_participants',
    'wardrobe_items', 'wardrobe_assignments', 'wardrobe_assignment_items',
    'financial_obligations', 'financial_payments'
  ])
order by ui.relname, ui.idx_scan desc, ui.indexrelname;

-- 3. Foreign keys whose columns are not the leading columns of a valid index.
-- These are candidates for review, not automatic recommendations: small or
-- write-heavy tables may intentionally remain without an extra index.
with foreign_keys as (
  select
    c.oid as constraint_oid,
    c.conrelid as table_oid,
    n.nspname as schema_name,
    r.relname as table_name,
    c.conname as constraint_name,
    c.conkey
  from pg_constraint c
  join pg_class r on r.oid = c.conrelid
  join pg_namespace n on n.oid = r.relnamespace
  where c.contype = 'f'
    and n.nspname = 'public'
), foreign_key_columns as (
  select
    fk.*,
    string_agg(a.attname, ', ' order by key_position.ordinality) as column_names
  from foreign_keys fk
  cross join lateral unnest(fk.conkey) with ordinality as key_position(attnum, ordinality)
  join pg_attribute a
    on a.attrelid = fk.table_oid
   and a.attnum = key_position.attnum
  group by fk.constraint_oid, fk.table_oid, fk.schema_name, fk.table_name,
           fk.constraint_name, fk.conkey
)
select
  fk.schema_name,
  fk.table_name,
  fk.constraint_name,
  fk.column_names
from foreign_key_columns fk
where not exists (
  select 1
  from pg_index i
  where i.indrelid = fk.table_oid
    and i.indisvalid
    and i.indisready
    and i.indpred is null
    and (i.indkey::smallint[])[0:cardinality(fk.conkey) - 1] = fk.conkey
)
order by fk.table_name, fk.constraint_name;

-- 4. Structurally equivalent indexes. Confirm constraints and workload before
-- removing anything; a result here is only a review candidate.
with index_signatures as (
  select
    n.nspname as schema_name,
    t.relname as table_name,
    x.indrelid,
    x.indkey::text as indexed_columns,
    x.indclass::text as operator_classes,
    x.indcollation::text as collations,
    x.indoption::text as options,
    coalesce(pg_get_expr(x.indexprs, x.indrelid), '') as expressions,
    coalesce(pg_get_expr(x.indpred, x.indrelid), '') as predicate,
    x.indisunique,
    x.indisprimary,
    i.relname as index_name,
    pg_relation_size(i.oid) as index_bytes
  from pg_index x
  join pg_class i on i.oid = x.indexrelid
  join pg_class t on t.oid = x.indrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and x.indisvalid
)
select
  schema_name,
  table_name,
  array_agg(index_name order by index_name) as equivalent_indexes,
  pg_size_pretty(sum(index_bytes)) as combined_size
from index_signatures
group by schema_name, table_name, indrelid, indexed_columns, operator_classes,
         collations, options, expressions, predicate, indisunique, indisprimary
having count(*) > 1
order by sum(index_bytes) desc, table_name;

-- 5. Planner-only samples for frequent application access paths.
-- Optionally set a society UUID for more representative estimates in this SQL
-- editor session:
-- select set_config('app.performance_society_id', '<SOCIETY_UUID>', false);

explain (format text, costs true)
select sm.id, sm.status, p.first_name, p.last_name
from public.society_members sm
join public.people p on p.id = sm.person_id
where sm.society_id = nullif(current_setting('app.performance_society_id', true), '')::uuid
  and sm.status = 'ACTIVE'
order by p.last_name, p.first_name
limit 100;

explain (format text, costs true)
select e.id, e.status, e.departure_at, e.created_at
from public.society_events e
where e.society_id = nullif(current_setting('app.performance_society_id', true), '')::uuid
  and e.status in ('DRAFT', 'APPROVED')
order by e.departure_at, e.created_at desc
limit 100;

explain (format text, costs true)
select wa.id, wa.status, wa.due_date, wai.wardrobe_item_id
from public.wardrobe_assignments wa
join public.wardrobe_assignment_items wai on wai.assignment_id = wa.id
where wa.society_id = nullif(current_setting('app.performance_society_id', true), '')::uuid
  and wa.status = 'ACTIVE'
order by wa.due_date nulls last, wa.id
limit 100;
