-- Stable fingerprint for all repository-owned schema objects through Phase 1.
with object_definitions as (
  select format(
    'column:%I.%I.%I:%s:%s:%s',
    n.nspname,
    c.relname,
    a.attname,
    pg_catalog.format_type(a.atttypid, a.atttypmod),
    a.attnotnull,
    coalesce(pg_get_expr(d.adbin, d.adrelid), '')
  ) as definition
  from pg_catalog.pg_attribute a
  join pg_catalog.pg_class c on c.oid = a.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  left join pg_catalog.pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  where n.nspname = 'public'
    and c.relname in ('identity_accounts', 'profiles')
    and a.attnum > 0
    and not a.attisdropped

  union all

  select format(
    'constraint:%I.%I:%s',
    n.nspname,
    c.relname,
    pg_get_constraintdef(con.oid, true)
  )
  from pg_catalog.pg_constraint con
  join pg_catalog.pg_class c on c.oid = con.conrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in ('identity_accounts', 'profiles')

  union all

  select format(
    'policy:%I.%I:%s:%s:%s:%s:%s',
    schemaname,
    tablename,
    policyname,
    cmd,
    roles,
    coalesce(qual, ''),
    coalesce(with_check, '')
  )
  from pg_catalog.pg_policies
  where schemaname = 'public'
    and tablename in ('identity_accounts', 'profiles')

  union all

  select format(
    'function:%I.%I:%s',
    n.nspname,
    p.proname,
    pg_get_functiondef(p.oid)
  )
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where (n.nspname, p.proname) in (
    ('private', 'set_updated_at'),
    ('private', 'bootstrap_identity_account'),
    ('public', 'complete_identity_onboarding')
  )

  union all

  select format('trigger:%s', pg_get_triggerdef(t.oid, true))
  from pg_catalog.pg_trigger t
  join pg_catalog.pg_class c on c.oid = t.tgrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where not t.tgisinternal
    and (
      (n.nspname = 'public' and c.relname in ('identity_accounts', 'profiles'))
      or (n.nspname = 'auth' and t.tgname = 'auth_user_bootstrap_identity_account')
    )
)
select
  md5(string_agg(definition, E'\n' order by definition)) as phase_1_schema_fingerprint,
  count(*)::integer as repository_object_count
from object_definitions;
