begin;
drop extension if exists pgtap;
create extension pgtap with schema public;
set local search_path = public;

select plan(31);

select has_table('public', 'identity_accounts', 'private account state table exists');
select has_table('public', 'profiles', 'public profile table exists');
select is(
  (select relrowsecurity from pg_class where oid = 'public.identity_accounts'::regclass),
  true,
  'identity accounts have RLS enabled'
);
select is(
  (select relrowsecurity from pg_class where oid = 'public.profiles'::regclass),
  true,
  'profiles have RLS enabled'
);
select col_is_pk('public', 'identity_accounts', 'user_id', 'identity user id is the primary key');
select col_is_pk('public', 'profiles', 'user_id', 'profile user id is the primary key');
select is(
  (
    select prosecdef
    from pg_proc
    where oid = 'public.complete_identity_onboarding(text,text,text,text)'::regprocedure
  ),
  false,
  'onboarding RPC is security invoker'
);
select is(
  has_function_privilege(
    'anon',
    (
      select p.oid
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'private'
        and p.proname = 'bootstrap_identity_account'
        and p.pronargs = 0
    ),
    'EXECUTE'
  ),
  false,
  'anon cannot execute the privileged auth trigger'
);
select is(
  has_table_privilege('anon', 'public.identity_accounts', 'SELECT'),
  false,
  'anon has no private account read privilege'
);
select is(
  has_table_privilege('anon', 'public.profiles', 'SELECT'),
  true,
  'anon can read public profiles'
);
select is(
  has_table_privilege('authenticated', 'public.identity_accounts', 'SELECT'),
  true,
  'authenticated users can read their account through RLS'
);
select is(
  has_table_privilege('authenticated', 'public.identity_accounts', 'INSERT'),
  true,
  'authenticated onboarding can insert its own account through RLS'
);
select is(
  has_table_privilege('authenticated', 'public.identity_accounts', 'UPDATE'),
  true,
  'authenticated users can update their account through RLS'
);
select is(
  has_table_privilege('authenticated', 'public.profiles', 'UPDATE'),
  true,
  'authenticated users can update their profile through RLS'
);
select is(
  has_table_privilege('authenticated', 'public.profiles', 'DELETE'),
  false,
  'authenticated users cannot delete profiles'
);
select is(
  has_function_privilege(
    'anon',
    'public.complete_identity_onboarding(text,text,text,text)',
    'EXECUTE'
  ),
  false,
  'anon cannot execute onboarding'
);

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '11111111-1111-4111-8111-111111111111',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'owner@lingkar.test',
    'not-a-real-password-hash',
    statement_timestamp(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'other@lingkar.test',
    'not-a-real-password-hash',
    statement_timestamp(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    statement_timestamp(),
    statement_timestamp()
  );

create temporary table identity_test_results (
  result_key text primary key,
  result_value integer not null
) on commit drop;
grant select, insert on table identity_test_results to authenticated;

create function pg_temp.try_conflicting_onboarding()
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
begin
  perform public.complete_identity_onboarding(
    'pemilik_lingkar',
    'Pengguna Lain',
    '18plus-v1',
    'closed-beta-v1'
  );
  return false;
exception
  when unique_violation then return true;
end;
$$;
grant execute on function pg_temp.try_conflicting_onboarding() to authenticated;

select is(
  (select count(*)::integer from public.identity_accounts),
  2,
  'auth trigger bootstraps one account per invited user'
);

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{}}',
  true
);

select is(
  (select count(*)::integer from public.identity_accounts),
  1,
  'owner sees only its private account row'
);

select is(
  (
    select (public.complete_identity_onboarding(
      '  Pemilik_Lingkar  ',
      '  Pemilik Lingkar  ',
      '18plus-v1',
      'closed-beta-v1'
    )).handle
  ),
  'pemilik_lingkar',
  'onboarding normalizes the unique handle'
);

select is(
  (
    select onboarding_completed_at is not null
      and age_attestation_version = '18plus-v1'
      and terms_version = 'closed-beta-v1'
    from public.identity_accounts
    where user_id = '11111111-1111-4111-8111-111111111111'
  ),
  true,
  'versioned 18+ and terms attestations complete atomically'
);

select public.complete_identity_onboarding(
  'pemilik_lingkar',
  'Pemilik Lingkar',
  '18plus-v1',
  'closed-beta-v1'
);

select is(
  (select count(*)::integer from public.profiles),
  1,
  'replaying onboarding is idempotent'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{}}',
  true
);

select is(
  (
    select count(*)::integer
    from public.identity_accounts
    where user_id = '11111111-1111-4111-8111-111111111111'
  ),
  0,
  'another user cannot read owner private state'
);
select is(
  (
    select count(*)::integer
    from public.profiles
    where user_id = '11111111-1111-4111-8111-111111111111'
  ),
  1,
  'another user can read the minimal public profile'
);
with changed as (
  update public.profiles
  set display_name = 'Diambil Alih'
  where user_id = '11111111-1111-4111-8111-111111111111'
  returning 1
)
insert into identity_test_results (result_key, result_value)
select 'other_profile_updates', count(*)::integer from changed;

select is(
  (select result_value from identity_test_results where result_key = 'other_profile_updates'),
  0,
  'another user cannot update owner profile'
);

select is(
  pg_temp.try_conflicting_onboarding(),
  true,
  'a duplicate normalized handle rejects the competing onboarding'
);
select is(
  (
    select onboarding_completed_at is null
    from public.identity_accounts
    where user_id = '22222222-2222-4222-8222-222222222222'
  ),
  true,
  'failed profile creation rolls back the age and terms attestation atomically'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{"system_role":"moderator"}}',
  true
);
select is(
  (
    select count(*)::integer
    from public.identity_accounts
    where user_id = '11111111-1111-4111-8111-111111111111'
  ),
  0,
  'moderator metadata grants no implicit private-account bypass'
);

reset role;
set local role anon;
select is(
  (
    select count(*)::integer
    from public.profiles
    where handle = 'pemilik_lingkar'
  ),
  1,
  'anon can read the public profile projection'
);
reset role;

select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public'
      and table_name in ('identity_accounts', 'profiles')
      and column_name ~* '(birth|dob|email|password)'
  ),
  0,
  'product identity tables store no date of birth, email, or password'
);

select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and (
        coalesce(qual, '') ~* 'auth[.]role[[:space:]]*[(]'
        or coalesce(with_check, '') ~* '(raw_)?user_metadata'
      )
  ),
  0,
  'policies avoid deprecated roles and user-editable metadata'
);

select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and cmd in ('UPDATE', 'ALL')
      and (qual is null or with_check is null)
  ),
  0,
  'every update policy has USING and WITH CHECK'
);

select * from finish();
rollback;
