-- Fail-closed Phase 3 RLS, Storage, privilege, and trusted-mutation assertions.
do $audit$
declare
  violations text;
  phase_3_tables constant text[] := array[
    'content_posts', 'content_post_revisions', 'content_media_assets',
    'content_polls', 'content_poll_options', 'content_poll_votes',
    'content_replies', 'content_reply_revisions', 'content_questions',
    'content_mentions', 'content_reactions', 'content_saves',
    'content_mutation_requests', 'content_rate_events', 'content_audit_events'
  ];
  phase_3_functions constant text[] := array[
    'register_content_media', 'create_content_post', 'edit_content_post',
    'delete_content_post', 'create_content_reply', 'edit_content_reply',
    'delete_content_reply', 'set_content_reaction', 'set_content_saved',
    'vote_content_poll', 'accept_content_answer'
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
  where schemaname in ('public', 'graphql_public', 'storage')
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
  where schemaname in ('public', 'graphql_public', 'storage')
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
  from unnest(phase_3_tables) table_name
  where has_table_privilege('anon', format('public.%I', table_name), 'SELECT')
    or has_table_privilege('authenticated', format('public.%I', table_name), 'INSERT')
    or has_table_privilege('authenticated', format('public.%I', table_name), 'UPDATE')
    or has_table_privilege('authenticated', format('public.%I', table_name), 'DELETE');
  if violations is not null then
    raise exception 'Phase 3 table grant boundary violated: %', violations;
  end if;

  select string_agg(procedure.proname, ', ')
    into violations
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
  where namespace.nspname = 'public'
    and procedure.proname = any(phase_3_functions)
    and (
      procedure.prosecdef
      or has_function_privilege('anon', procedure.oid, 'EXECUTE')
      or has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
      or not has_function_privilege('service_role', procedure.oid, 'EXECUTE')
    );
  if violations is not null then
    raise exception 'Trusted content RPC boundary violated: %', violations;
  end if;

  if has_schema_privilege('anon', 'private', 'USAGE')
    or has_schema_privilege('authenticated', 'private', 'USAGE') then
    raise exception 'Client roles can use the private schema';
  end if;

  if has_table_privilege('authenticated', 'public.content_mutation_requests', 'SELECT')
    or has_table_privilege('authenticated', 'public.content_rate_events', 'SELECT') then
    raise exception 'Browser can inspect internal idempotency or rate-limit state';
  end if;

  if has_table_privilege('authenticated', 'public.content_audit_events', 'INSERT')
    or has_table_privilege('authenticated', 'public.content_audit_events', 'UPDATE')
    or has_table_privilege('authenticated', 'public.content_audit_events', 'DELETE') then
    raise exception 'Browser role can forge or mutate content audit events';
  end if;

  if not exists (
    select 1 from storage.buckets bucket
    where bucket.id = 'content-media'
      and not bucket.public
      and bucket.file_size_limit = 5242880
  ) then
    raise exception 'Private content-media bucket contract is missing';
  end if;

  if (select count(*) from pg_catalog.pg_policies
      where schemaname = 'storage' and tablename = 'objects'
        and policyname like 'content_media_objects_%') <> 4 then
    raise exception 'Storage ownership policy matrix is incomplete';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = any(phase_3_tables)
      and column_name ~* '(email|password|secret|access_token|refresh_token)'
  ) then
    raise exception 'Phase 3 product tables contain prohibited credential data';
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
  (select count(*) from pg_catalog.pg_policies where schemaname = 'public') as public_policy_count,
  (select count(*) from pg_catalog.pg_policies where schemaname = 'storage' and policyname like 'content_media_objects_%') as storage_policy_count,
  'PASS' as result
from pg_catalog.pg_class relation
join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace;
