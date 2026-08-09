-- Fail-closed Phase 2 database, RLS, privilege, and trusted-mutation assertions.
do $audit$
declare
  violations text;
  phase_2_tables constant text[] := array[
    'spaces', 'space_memberships', 'space_rules', 'space_join_requests',
    'space_invitations', 'space_bans', 'space_reputation_entries',
    'space_reputation_balances', 'space_audit_events'
  ];
  phase_2_functions constant text[] := array[
    'create_space', 'join_space', 'leave_space', 'review_space_join_request',
    'invite_space_member', 'set_space_member_role', 'transfer_space_ownership',
    'ban_space_member', 'unban_space_member', 'add_space_reputation',
    'upsert_space_rule', 'remove_space_rule'
  ];
begin
  select string_agg(format('%I.%I', namespace.nspname, relation.relname), ', ')
    into violations
  from pg_catalog.pg_class relation
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where namespace.nspname in ('public', 'graphql_public')
    and relation.relkind in ('r', 'p')
    and not relation.relrowsecurity;
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

  select string_agg(format('%I.%I', namespace.nspname, procedure.proname), ', ')
    into violations
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
  where namespace.nspname in ('public', 'graphql_public') and procedure.prosecdef;
  if violations is not null then
    raise exception 'SECURITY DEFINER functions found in exposed schemas: %', violations;
  end if;

  select string_agg(table_name, ', ')
    into violations
  from unnest(phase_2_tables) table_name
  where has_table_privilege('anon', format('public.%I', table_name), 'SELECT')
    or has_table_privilege('authenticated', format('public.%I', table_name), 'INSERT')
    or has_table_privilege('authenticated', format('public.%I', table_name), 'UPDATE')
    or has_table_privilege('authenticated', format('public.%I', table_name), 'DELETE');
  if violations is not null then
    raise exception 'Phase 2 table grant boundary violated: %', violations;
  end if;

  select string_agg(procedure.proname, ', ')
    into violations
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
  where namespace.nspname = 'public'
    and procedure.proname = any(phase_2_functions)
    and (
      procedure.prosecdef
      or has_function_privilege('anon', procedure.oid, 'EXECUTE')
      or has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
      or not has_function_privilege('service_role', procedure.oid, 'EXECUTE')
    );
  if violations is not null then
    raise exception 'Trusted mutation RPC boundary violated: %', violations;
  end if;

  if has_schema_privilege('anon', 'private', 'USAGE')
    or has_schema_privilege('authenticated', 'private', 'USAGE') then
    raise exception 'Client roles can use the private schema';
  end if;

  if has_table_privilege('authenticated', 'public.space_audit_events', 'INSERT')
    or has_table_privilege('authenticated', 'public.space_audit_events', 'UPDATE')
    or has_table_privilege('authenticated', 'public.space_audit_events', 'DELETE') then
    raise exception 'Browser role can forge or mutate space audit events';
  end if;

  if has_table_privilege('authenticated', 'public.space_reputation_entries', 'INSERT')
    or has_table_privilege('authenticated', 'public.space_reputation_entries', 'UPDATE')
    or has_table_privilege('authenticated', 'public.space_reputation_entries', 'DELETE') then
    raise exception 'Browser role can bypass the reputation ledger RPC';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = any(phase_2_tables)
      and column_name ~* '(email|password|secret|token)'
  ) then
    raise exception 'Phase 2 product tables contain prohibited secret or credential data';
  end if;
end;
$audit$;

select
  current_database() as database_name,
  current_setting('server_version') as server_version,
  count(*) filter (where namespace.nspname in ('public', 'graphql_public') and relation.relkind in ('r', 'p'))
    as exposed_table_count,
  count(*) filter (
    where namespace.nspname in ('public', 'graphql_public')
      and relation.relkind in ('r', 'p')
      and relation.relrowsecurity
  ) as exposed_tables_with_rls,
  (select count(*) from pg_catalog.pg_policies where schemaname = 'public') as policy_count,
  'PASS' as result
from pg_catalog.pg_class relation
join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace;
