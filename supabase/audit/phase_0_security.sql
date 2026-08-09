-- Read-only assertions for a linked Phase 0 audit database.
-- Every violation raises an exception so the CLI exits non-zero.
do $audit$
declare
  violations text;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ' order by n.nspname, c.relname)
    into violations
  from pg_catalog.pg_class as c
  join pg_catalog.pg_namespace as n on n.oid = c.relnamespace
  where n.nspname in ('public', 'graphql_public')
    and c.relkind in ('r', 'p')
    and not c.relrowsecurity;

  if violations is not null then
    raise exception 'Exposed tables without RLS: %', violations;
  end if;

  select string_agg(format('%I.%I/%s', schemaname, tablename, policyname), ', ')
    into violations
  from pg_catalog.pg_policies
  where schemaname in ('public', 'graphql_public')
    and (
      coalesce(qual, '') ~* 'auth[.]role[[:space:]]*[(]'
      or coalesce(with_check, '') ~* 'auth[.]role[[:space:]]*[(]'
      or coalesce(qual, '') ~* '(raw_)?user_metadata'
      or coalesce(with_check, '') ~* '(raw_)?user_metadata'
    );

  if violations is not null then
    raise exception 'Deprecated or user-editable authorization in policies: %', violations;
  end if;

  select string_agg(format('%I.%I/%s', schemaname, tablename, policyname), ', ')
    into violations
  from pg_catalog.pg_policies
  where schemaname in ('public', 'graphql_public')
    and cmd in ('UPDATE', 'ALL')
    and (qual is null or with_check is null);

  if violations is not null then
    raise exception 'UPDATE/ALL policies missing USING or WITH CHECK: %', violations;
  end if;

  select string_agg(format('%I.%I', n.nspname, p.proname), ', ' order by n.nspname, p.proname)
    into violations
  from pg_catalog.pg_proc as p
  join pg_catalog.pg_namespace as n on n.oid = p.pronamespace
  where n.nspname in ('public', 'graphql_public')
    and p.prosecdef;

  if violations is not null then
    raise exception 'SECURITY DEFINER functions found in exposed schemas: %', violations;
  end if;

  if has_schema_privilege('anon', 'private', 'USAGE')
    or has_schema_privilege('authenticated', 'private', 'USAGE') then
    raise exception 'Client roles can use the private schema';
  end if;
end;
$audit$;

select
  current_database() as database_name,
  current_setting('server_version') as server_version,
  count(*) filter (where n.nspname in ('public', 'graphql_public') and c.relkind in ('r', 'p'))
    as exposed_table_count,
  count(*) filter (where n.nspname = 'private' and c.relkind in ('r', 'p'))
    as private_table_count
from pg_catalog.pg_class as c
join pg_catalog.pg_namespace as n on n.oid = c.relnamespace;
