-- Phase 1: invite-only identity, versioned 18+ attestation, and public profile cards.
-- Hosted Auth must keep public signups disabled; invitations are issued only by trusted operators.

create table public.identity_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  onboarding_completed_at timestamptz,
  age_attested_at timestamptz,
  age_attestation_version text,
  terms_accepted_at timestamptz,
  terms_version text,
  locale text not null default 'id-ID',
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint identity_accounts_age_version_check
    check (age_attestation_version is null or age_attestation_version = '18plus-v1'),
  constraint identity_accounts_terms_version_check
    check (terms_version is null or terms_version = 'closed-beta-v1'),
  constraint identity_accounts_locale_check
    check (locale ~ '^[a-z]{2}(?:-[A-Z]{2})?$'),
  constraint identity_accounts_onboarding_state_check
    check (
      (
        onboarding_completed_at is null
        and age_attested_at is null
        and age_attestation_version is null
        and terms_accepted_at is null
        and terms_version is null
      )
      or
      (
        onboarding_completed_at is not null
        and age_attested_at is not null
        and age_attestation_version is not null
        and terms_accepted_at is not null
        and terms_version is not null
      )
    )
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  handle text not null,
  display_name text not null,
  bio text not null default '',
  avatar_path text,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint profiles_handle_unique unique (handle),
  constraint profiles_handle_format_check
    check (
      handle = lower(btrim(handle))
      and handle ~ '^[a-z][a-z0-9_]{2,29}$'
    ),
  constraint profiles_display_name_length_check
    check (char_length(btrim(display_name)) between 2 and 50),
  constraint profiles_bio_length_check
    check (char_length(bio) <= 280),
  constraint profiles_avatar_path_check
    check (
      avatar_path is null
      or (
        char_length(avatar_path) between 1 and 255
        and avatar_path !~ '(^/|[.][.]|://)'
      )
    )
);

alter table public.identity_accounts enable row level security;
alter table public.identity_accounts force row level security;
alter table public.profiles enable row level security;
alter table public.profiles force row level security;

revoke all on table public.identity_accounts from public, anon, authenticated;
revoke all on table public.profiles from public, anon, authenticated;

grant select, insert, update on table public.identity_accounts to authenticated;
grant select on table public.profiles to anon, authenticated;
grant insert, update on table public.profiles to authenticated;
grant all on table public.identity_accounts, public.profiles to service_role;

create policy identity_accounts_owner_select
on public.identity_accounts
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy identity_accounts_owner_insert
on public.identity_accounts
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy identity_accounts_owner_update
on public.identity_accounts
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy profiles_public_select
on public.profiles
for select
to anon, authenticated
using (true);

create policy profiles_owner_insert
on public.profiles
for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy profiles_owner_update
on public.profiles
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create trigger identity_accounts_set_updated_at
before update on public.identity_accounts
for each row execute function private.set_updated_at();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create or replace function private.bootstrap_identity_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.identity_accounts (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke execute on function private.bootstrap_identity_account() from public, anon, authenticated;
grant execute on function private.bootstrap_identity_account() to supabase_auth_admin, service_role;

create trigger auth_user_bootstrap_identity_account
after insert on auth.users
for each row execute function private.bootstrap_identity_account();

-- Backfill makes the migration deterministic for projects that already contain invited users.
insert into public.identity_accounts (user_id)
select users.id
from auth.users
on conflict (user_id) do nothing;

create or replace function public.complete_identity_onboarding(
  requested_handle text,
  requested_display_name text,
  accepted_age_version text,
  accepted_terms_version text
)
returns public.profiles
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  normalized_handle text := lower(btrim(requested_handle));
  normalized_display_name text := btrim(requested_display_name);
  completed_at timestamptz := statement_timestamp();
  existing_account public.identity_accounts%rowtype;
  resulting_profile public.profiles%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;

  if normalized_handle !~ '^[a-z][a-z0-9_]{2,29}$' then
    raise exception using errcode = '22023', message = 'invalid_handle';
  end if;

  if char_length(normalized_display_name) not between 2 and 50 then
    raise exception using errcode = '22023', message = 'invalid_display_name';
  end if;

  if accepted_age_version <> '18plus-v1' then
    raise exception using errcode = '22023', message = 'age_attestation_required';
  end if;

  if accepted_terms_version <> 'closed-beta-v1' then
    raise exception using errcode = '22023', message = 'terms_acceptance_required';
  end if;

  insert into public.identity_accounts (user_id)
  values (actor_id)
  on conflict (user_id) do nothing;

  update public.identity_accounts
  set
    onboarding_completed_at = completed_at,
    age_attested_at = completed_at,
    age_attestation_version = accepted_age_version,
    terms_accepted_at = completed_at,
    terms_version = accepted_terms_version
  where user_id = actor_id
    and onboarding_completed_at is null;

  if not found then
    select *
    into strict existing_account
    from public.identity_accounts
    where user_id = actor_id;

    if existing_account.age_attestation_version <> accepted_age_version
      or existing_account.terms_version <> accepted_terms_version then
      raise exception using errcode = '22023', message = 'onboarding_version_mismatch';
    end if;
  end if;

  insert into public.profiles (user_id, handle, display_name)
  values (actor_id, normalized_handle, normalized_display_name)
  on conflict (user_id) do nothing;

  select *
  into strict resulting_profile
  from public.profiles
  where user_id = actor_id;

  if resulting_profile.handle <> normalized_handle
    or resulting_profile.display_name <> normalized_display_name then
    raise exception using errcode = '22023', message = 'onboarding_already_completed';
  end if;

  return resulting_profile;
end;
$$;

revoke execute on function public.complete_identity_onboarding(text, text, text, text)
from public, anon;
grant execute on function public.complete_identity_onboarding(text, text, text, text)
to authenticated, service_role;
