-- Stable fingerprint for repository-owned Phase 0 database objects.
-- Extension versions are intentionally excluded because Supabase manages them.
with object_definitions as (
  select format('schema:%I', n.nspname) as definition
  from pg_namespace n
  where n.nspname = 'private'

  union all

  select format(
    'function:%I.%I:%s',
    n.nspname,
    p.proname,
    pg_get_functiondef(p.oid)
  )
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
)
select
  md5(string_agg(definition, E'\n' order by definition)) as phase_0_schema_fingerprint,
  count(*)::integer as repository_object_count
from object_definitions;
