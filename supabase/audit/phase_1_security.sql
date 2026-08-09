-- Fail-closed Phase 1 database and RLS assertions for a linked audit database.
do $audit$
declare
  violations text;
  bootstrap_oid oid;
  onboarding_oid oid;
begin
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ' order by n.nspname, c.relname)
    into violations
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
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
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('public', 'graphql_public')
    and p.prosecdef;

  if violations is not null then
    raise exception 'SECURITY DEFINER functions found in exposed schemas: %', violations;
  end if;

  bootstrap_oid := 'private.bootstrap_identity_account()'::regprocedure;
  onboarding_oid := 'public.complete_identity_onboarding(text,text,text,text)'::regprocedure;

  if not (select prosecdef from pg_catalog.pg_proc where oid = bootstrap_oid) then
    raise exception 'Auth bootstrap trigger is not SECURITY DEFINER';
  end if;

  if (
    select proconfig is distinct from array['search_path=""']
    from pg_catalog.pg_proc
    where oid = bootstrap_oid
  ) then
    raise exception 'Auth bootstrap trigger does not have an empty search path';
  end if;

  if has_function_privilege('anon', bootstrap_oid, 'EXECUTE')
    or has_function_privilege('authenticated', bootstrap_oid, 'EXECUTE') then
    raise exception 'Client roles can execute the privileged auth bootstrap trigger';
  end if;

  if (select prosecdef from pg_catalog.pg_proc where oid = onboarding_oid) then
    raise exception 'Public onboarding RPC must remain SECURITY INVOKER';
  end if;

  if has_table_privilege('anon', 'public.identity_accounts', 'SELECT')
    or has_table_privilege('anon', 'public.identity_accounts', 'INSERT')
    or has_table_privilege('anon', 'public.identity_accounts', 'UPDATE') then
    raise exception 'Anon has privileges on private identity account state';
  end if;

  if not has_table_privilege('anon', 'public.profiles', 'SELECT') then
    raise exception 'Anon cannot read the intended public profile projection';
  end if;

  if has_table_privilege('authenticated', 'public.profiles', 'DELETE')
    or has_table_privilege('authenticated', 'public.identity_accounts', 'DELETE') then
    raise exception 'Authenticated users received destructive table privileges';
  end if;

  select string_agg(format('%I.%I', table_name, column_name), ', ')
    into violations
  from information_schema.columns
  where table_schema = 'public'
    and table_name in ('identity_accounts', 'profiles')
    and column_name ~* '(birth|dob|email|password)';

  if violations is not null then
    raise exception 'Product identity tables contain prohibited identity data: %', violations;
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
  count(*) filter (
    where n.nspname in ('public', 'graphql_public')
      and c.relkind in ('r', 'p')
      and c.relrowsecurity
  ) as exposed_tables_with_rls,
  (select count(*) from pg_catalog.pg_policies where schemaname = 'public') as policy_count,
  'PASS' as result
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace;
