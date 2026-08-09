-- Phase 2: community spaces, membership controls, contextual reputation, and moderation baseline.

create table public.spaces (
  id bigint generated always as identity primary key,
  slug text not null,
  name text not null,
  description text not null default '',
  join_policy text not null default 'request',
  discoverability text not null default 'public',
  lifecycle text not null default 'active',
  owner_id uuid not null references public.profiles(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint spaces_slug_unique unique (slug),
  constraint spaces_slug_format_check
    check (slug = lower(btrim(slug)) and slug ~ '^[a-z][a-z0-9-]{2,47}$'),
  constraint spaces_name_length_check check (char_length(btrim(name)) between 3 and 80),
  constraint spaces_description_length_check check (char_length(description) <= 1000),
  constraint spaces_join_policy_check check (join_policy in ('open', 'request', 'invite')),
  constraint spaces_discoverability_check check (discoverability in ('public', 'unlisted', 'private')),
  constraint spaces_lifecycle_check check (lifecycle in ('active', 'archived'))
);

create table public.space_memberships (
  space_id bigint not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  role text not null default 'member',
  status text not null default 'active',
  joined_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  primary key (space_id, user_id),
  constraint space_memberships_role_check check (role in ('owner', 'moderator', 'member')),
  constraint space_memberships_status_check check (status in ('active', 'left'))
);

create unique index space_memberships_one_active_owner_idx
on public.space_memberships (space_id)
where role = 'owner' and status = 'active';

create index space_memberships_user_active_idx
on public.space_memberships (user_id, space_id)
where status = 'active';

create table public.space_rules (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  position smallint not null,
  title text not null,
  body text not null,
  is_required boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint space_rules_position_unique unique (space_id, position),
  constraint space_rules_position_check check (position between 1 and 50),
  constraint space_rules_title_length_check check (char_length(btrim(title)) between 3 and 100),
  constraint space_rules_body_length_check check (char_length(btrim(body)) between 3 and 1000)
);

create index space_rules_space_id_idx on public.space_rules (space_id);

create table public.space_join_requests (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  status text not null default 'pending',
  decided_by uuid references public.profiles(user_id) on delete set null,
  created_at timestamptz not null default statement_timestamp(),
  decided_at timestamptz,
  constraint space_join_requests_status_check
    check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  constraint space_join_requests_decision_check
    check (
      (status = 'pending' and decided_by is null and decided_at is null)
      or (status = 'cancelled' and decided_by is null and decided_at is not null)
      or (status in ('approved', 'rejected') and decided_by is not null and decided_at is not null)
    )
);

create unique index space_join_requests_one_pending_idx
on public.space_join_requests (space_id, user_id)
where status = 'pending';

create index space_join_requests_space_status_created_idx
on public.space_join_requests (space_id, status, created_at);

create table public.space_invitations (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  invited_by uuid not null references public.profiles(user_id) on delete restrict,
  status text not null default 'pending',
  expires_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  responded_at timestamptz,
  constraint space_invitations_status_check
    check (status in ('pending', 'accepted', 'declined', 'revoked')),
  constraint space_invitations_response_check
    check (
      (status = 'pending' and responded_at is null)
      or (status <> 'pending' and responded_at is not null)
    )
);

create unique index space_invitations_one_pending_idx
on public.space_invitations (space_id, user_id)
where status = 'pending';

create index space_invitations_user_status_idx
on public.space_invitations (user_id, status, created_at);

create table public.space_bans (
  space_id bigint not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  banned_by uuid not null references public.profiles(user_id) on delete restrict,
  reason text not null,
  expires_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(user_id) on delete set null,
  primary key (space_id, user_id),
  constraint space_bans_reason_length_check check (char_length(btrim(reason)) between 3 and 500),
  constraint space_bans_revocation_check
    check (
      (revoked_at is null and revoked_by is null)
      or (revoked_at is not null and revoked_by is not null)
    )
);

create index space_bans_user_active_idx
on public.space_bans (user_id, space_id)
where revoked_at is null;

create table public.space_reputation_entries (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  actor_id uuid not null references public.profiles(user_id) on delete restrict,
  delta smallint not null,
  reason text not null,
  idempotency_key uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint space_reputation_entries_idempotency_unique unique (space_id, idempotency_key),
  constraint space_reputation_entries_delta_check check (delta between -100 and 100 and delta <> 0),
  constraint space_reputation_entries_reason_check check (char_length(btrim(reason)) between 3 and 200)
);

create index space_reputation_entries_space_user_created_idx
on public.space_reputation_entries (space_id, user_id, created_at desc);

create table public.space_reputation_balances (
  space_id bigint not null references public.spaces(id) on delete cascade,
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  score bigint not null default 0,
  updated_at timestamptz not null default statement_timestamp(),
  primary key (space_id, user_id)
);

create index space_reputation_balances_user_idx
on public.space_reputation_balances (user_id, space_id);

create table public.space_audit_events (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  actor_id uuid not null references public.profiles(user_id) on delete restrict,
  subject_user_id uuid references public.profiles(user_id) on delete set null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  constraint space_audit_events_type_check
    check (
      event_type in (
        'space_created', 'space_updated', 'space_archived', 'rule_upserted', 'rule_removed',
        'join_requested', 'join_approved', 'join_rejected', 'member_joined', 'member_left',
        'member_invited', 'invitation_accepted', 'member_role_changed', 'ownership_transferred',
        'member_banned', 'member_unbanned', 'reputation_changed'
      )
    ),
  constraint space_audit_events_details_object_check
    check (jsonb_typeof(details) = 'object')
);

create index space_audit_events_space_created_idx
on public.space_audit_events (space_id, created_at desc);

create index space_audit_events_subject_created_idx
on public.space_audit_events (subject_user_id, created_at desc)
where subject_user_id is not null;

create index spaces_owner_id_idx on public.spaces (owner_id);
create index space_join_requests_user_id_idx on public.space_join_requests (user_id);
create index space_join_requests_decided_by_idx on public.space_join_requests (decided_by)
where decided_by is not null;
create index space_invitations_invited_by_idx on public.space_invitations (invited_by);
create index space_bans_banned_by_idx on public.space_bans (banned_by);
create index space_bans_revoked_by_idx on public.space_bans (revoked_by)
where revoked_by is not null;
create index space_reputation_entries_user_id_idx on public.space_reputation_entries (user_id);
create index space_reputation_entries_actor_id_idx on public.space_reputation_entries (actor_id);
create index space_audit_events_actor_id_idx on public.space_audit_events (actor_id);

create trigger spaces_set_updated_at
before update on public.spaces
for each row execute function private.set_updated_at();

create trigger space_memberships_set_updated_at
before update on public.space_memberships
for each row execute function private.set_updated_at();

create trigger space_rules_set_updated_at
before update on public.space_rules
for each row execute function private.set_updated_at();

create or replace function private.is_active_space_member(target_space_id bigint, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = target_user_id
      and membership.status = 'active'
  )
  and not exists (
    select 1
    from public.space_bans ban
    where ban.space_id = target_space_id
      and ban.user_id = target_user_id
      and ban.revoked_at is null
      and (ban.expires_at is null or ban.expires_at > statement_timestamp())
  );
$$;

create or replace function private.is_space_moderator(target_space_id bigint, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = target_user_id
      and membership.status = 'active'
      and membership.role in ('owner', 'moderator')
  )
  and not exists (
    select 1
    from public.space_bans ban
    where ban.space_id = target_space_id
      and ban.user_id = target_user_id
      and ban.revoked_at is null
      and (ban.expires_at is null or ban.expires_at > statement_timestamp())
  );
$$;

create or replace function private.apply_space_reputation_entry()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.space_reputation_balances (space_id, user_id, score)
  values (new.space_id, new.user_id, new.delta)
  on conflict (space_id, user_id) do update
  set
    score = public.space_reputation_balances.score + excluded.score,
    updated_at = statement_timestamp();
  return new;
end;
$$;

revoke execute on function private.is_active_space_member(bigint, uuid) from public, anon;
revoke execute on function private.is_space_moderator(bigint, uuid) from public, anon;
revoke execute on function private.apply_space_reputation_entry() from public, anon, authenticated;
grant execute on function private.is_active_space_member(bigint, uuid) to authenticated, service_role;
grant execute on function private.is_space_moderator(bigint, uuid) to authenticated, service_role;
grant execute on function private.apply_space_reputation_entry() to service_role;

create trigger space_reputation_entries_apply_balance
after insert on public.space_reputation_entries
for each row execute function private.apply_space_reputation_entry();

alter table public.spaces enable row level security;
alter table public.spaces force row level security;
alter table public.space_memberships enable row level security;
alter table public.space_memberships force row level security;
alter table public.space_rules enable row level security;
alter table public.space_rules force row level security;
alter table public.space_join_requests enable row level security;
alter table public.space_join_requests force row level security;
alter table public.space_invitations enable row level security;
alter table public.space_invitations force row level security;
alter table public.space_bans enable row level security;
alter table public.space_bans force row level security;
alter table public.space_reputation_entries enable row level security;
alter table public.space_reputation_entries force row level security;
alter table public.space_reputation_balances enable row level security;
alter table public.space_reputation_balances force row level security;
alter table public.space_audit_events enable row level security;
alter table public.space_audit_events force row level security;

revoke all on table public.spaces from public, anon, authenticated;
revoke all on table public.space_memberships from public, anon, authenticated;
revoke all on table public.space_rules from public, anon, authenticated;
revoke all on table public.space_join_requests from public, anon, authenticated;
revoke all on table public.space_invitations from public, anon, authenticated;
revoke all on table public.space_bans from public, anon, authenticated;
revoke all on table public.space_reputation_entries from public, anon, authenticated;
revoke all on table public.space_reputation_balances from public, anon, authenticated;
revoke all on table public.space_audit_events from public, anon, authenticated;

grant select on table public.spaces, public.space_memberships, public.space_rules,
  public.space_join_requests, public.space_invitations, public.space_bans,
  public.space_reputation_entries, public.space_reputation_balances, public.space_audit_events
to authenticated;

grant all on table public.spaces, public.space_memberships, public.space_rules,
  public.space_join_requests, public.space_invitations, public.space_bans,
  public.space_reputation_entries, public.space_reputation_balances, public.space_audit_events
to service_role;

grant usage, select on all sequences in schema public to service_role;

create policy spaces_authenticated_select
on public.spaces
for select
to authenticated
using (
  (lifecycle = 'active' and discoverability in ('public', 'unlisted'))
  or (select private.is_active_space_member(id, (select auth.uid())))
);

create policy space_memberships_member_select
on public.space_memberships
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_active_space_member(space_id, (select auth.uid())))
);

create policy space_rules_member_select
on public.space_rules
for select
to authenticated
using (
  exists (
    select 1
    from public.spaces space
    where space.id = space_rules.space_id
      and (
        (space.lifecycle = 'active' and space.discoverability in ('public', 'unlisted'))
        or (select private.is_active_space_member(space.id, (select auth.uid())))
      )
  )
);

create policy space_join_requests_subject_or_moderator_select
on public.space_join_requests
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_space_moderator(space_id, (select auth.uid())))
);

create policy space_invitations_subject_or_moderator_select
on public.space_invitations
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_space_moderator(space_id, (select auth.uid())))
);

create policy space_bans_subject_or_moderator_select
on public.space_bans
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_space_moderator(space_id, (select auth.uid())))
);

create policy space_reputation_entries_subject_or_moderator_select
on public.space_reputation_entries
for select
to authenticated
using (
  user_id = (select auth.uid())
  or (select private.is_space_moderator(space_id, (select auth.uid())))
);

create policy space_reputation_balances_member_select
on public.space_reputation_balances
for select
to authenticated
using ((select private.is_active_space_member(space_id, (select auth.uid()))));

create policy space_audit_events_subject_or_moderator_select
on public.space_audit_events
for select
to authenticated
using (
  subject_user_id = (select auth.uid())
  or (select private.is_space_moderator(space_id, (select auth.uid())))
);

create or replace function public.create_space(
  acting_user_id uuid,
  requested_slug text,
  requested_name text,
  requested_description text,
  requested_join_policy text default 'request',
  requested_discoverability text default 'public'
)
returns public.spaces
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  normalized_slug text := lower(btrim(requested_slug));
  normalized_name text := btrim(requested_name);
  created_space public.spaces%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.identity_accounts account
    where account.user_id = actor_id and account.onboarding_completed_at is not null
  ) then
    raise exception using errcode = '42501', message = 'onboarding_required';
  end if;

  insert into public.spaces (slug, name, description, join_policy, discoverability, owner_id)
  values (
    normalized_slug,
    normalized_name,
    coalesce(requested_description, ''),
    requested_join_policy,
    requested_discoverability,
    actor_id
  )
  returning * into created_space;

  insert into public.space_memberships (space_id, user_id, role)
  values (created_space.id, actor_id, 'owner');

  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
  values (created_space.id, actor_id, actor_id, 'space_created');

  return created_space;
end;
$$;

create or replace function public.join_space(acting_user_id uuid, target_space_id bigint)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  target_space public.spaces%rowtype;
  pending_invitation_id bigint;
begin
  if actor_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.identity_accounts account
    where account.user_id = actor_id and account.onboarding_completed_at is not null
  ) then
    raise exception using errcode = '42501', message = 'onboarding_required';
  end if;

  select * into strict target_space from public.spaces where id = target_space_id for update;
  if target_space.lifecycle <> 'active' then
    raise exception using errcode = '55000', message = 'space_not_active';
  end if;
  if exists (
    select 1 from public.space_bans ban
    where ban.space_id = target_space_id
      and ban.user_id = actor_id
      and ban.revoked_at is null
      and (ban.expires_at is null or ban.expires_at > statement_timestamp())
  ) then
    raise exception using errcode = '42501', message = 'space_membership_banned';
  end if;
  if exists (
    select 1 from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = actor_id
      and membership.status = 'active'
  ) then
    return 'already_member';
  end if;

  select invitation.id into pending_invitation_id
  from public.space_invitations invitation
  where invitation.space_id = target_space_id
    and invitation.user_id = actor_id
    and invitation.status = 'pending'
    and (invitation.expires_at is null or invitation.expires_at > statement_timestamp())
  order by invitation.created_at desc
  limit 1
  for update;

  if pending_invitation_id is not null then
    update public.space_invitations
    set status = 'accepted', responded_at = statement_timestamp()
    where id = pending_invitation_id;
  elsif target_space.join_policy = 'request' then
    if not exists (
      select 1 from public.space_join_requests request
      where request.space_id = target_space_id
        and request.user_id = actor_id
        and request.status = 'pending'
    ) then
      insert into public.space_join_requests (space_id, user_id)
      values (target_space_id, actor_id);
      insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
      values (target_space_id, actor_id, actor_id, 'join_requested');
    end if;
    return 'requested';
  elsif target_space.join_policy = 'invite' then
    raise exception using errcode = '42501', message = 'space_invitation_required';
  end if;

  insert into public.space_memberships (space_id, user_id, role, status)
  values (target_space_id, actor_id, 'member', 'active')
  on conflict (space_id, user_id) do update
  set role = 'member', status = 'active', joined_at = statement_timestamp();

  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
  values (
    target_space_id,
    actor_id,
    actor_id,
    case when pending_invitation_id is not null then 'invitation_accepted' else 'member_joined' end
  );
  return 'joined';
end;
$$;

create or replace function public.leave_space(acting_user_id uuid, target_space_id bigint)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  membership_role text;
begin
  if actor_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  select membership.role into membership_role
  from public.space_memberships membership
  where membership.space_id = target_space_id
    and membership.user_id = actor_id
    and membership.status = 'active'
  for update;
  if membership_role is null then return; end if;
  if membership_role = 'owner' then
    raise exception using errcode = '55000', message = 'owner_must_transfer_first';
  end if;
  update public.space_memberships
  set status = 'left'
  where space_id = target_space_id and user_id = actor_id;
  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
  values (target_space_id, actor_id, actor_id, 'member_left');
end;
$$;

create or replace function public.review_space_join_request(
  acting_user_id uuid,
  target_request_id bigint,
  decision text
)
returns public.space_join_requests
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  target_request public.space_join_requests%rowtype;
begin
  if decision not in ('approved', 'rejected') then
    raise exception using errcode = '22023', message = 'invalid_join_decision';
  end if;
  select * into strict target_request
  from public.space_join_requests where id = target_request_id for update;
  if not private.is_space_moderator(target_request.space_id, actor_id) then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  if target_request.status <> 'pending' then return target_request; end if;
  if decision = 'approved' and exists (
    select 1 from public.space_bans ban
    where ban.space_id = target_request.space_id
      and ban.user_id = target_request.user_id
      and ban.revoked_at is null
      and (ban.expires_at is null or ban.expires_at > statement_timestamp())
  ) then
    raise exception using errcode = '42501', message = 'space_membership_banned';
  end if;

  update public.space_join_requests
  set status = decision, decided_by = actor_id, decided_at = statement_timestamp()
  where id = target_request_id
  returning * into target_request;

  if decision = 'approved' then
    insert into public.space_memberships (space_id, user_id, role, status)
    values (target_request.space_id, target_request.user_id, 'member', 'active')
    on conflict (space_id, user_id) do update
    set role = 'member', status = 'active', joined_at = statement_timestamp();
  end if;

  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
  values (
    target_request.space_id,
    actor_id,
    target_request.user_id,
    case when decision = 'approved' then 'join_approved' else 'join_rejected' end
  );
  return target_request;
end;
$$;

create or replace function public.invite_space_member(
  acting_user_id uuid,
  target_space_id bigint,
  target_user_id uuid,
  invitation_expires_at timestamptz default null
)
returns public.space_invitations
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  invitation public.space_invitations%rowtype;
begin
  if not private.is_space_moderator(target_space_id, actor_id) then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  if not exists (select 1 from public.profiles profile where profile.user_id = target_user_id) then
    raise exception using errcode = '23503', message = 'profile_not_found';
  end if;
  if exists (
    select 1 from public.space_bans ban
    where ban.space_id = target_space_id
      and ban.user_id = target_user_id
      and ban.revoked_at is null
      and (ban.expires_at is null or ban.expires_at > statement_timestamp())
  ) then
    raise exception using errcode = '42501', message = 'space_membership_banned';
  end if;
  if exists (
    select 1 from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = target_user_id
      and membership.status = 'active'
  ) then
    raise exception using errcode = '23505', message = 'already_space_member';
  end if;

  update public.space_invitations
  set status = 'revoked', responded_at = statement_timestamp()
  where space_id = target_space_id and user_id = target_user_id and status = 'pending';
  insert into public.space_invitations (space_id, user_id, invited_by, expires_at)
  values (target_space_id, target_user_id, actor_id, invitation_expires_at)
  returning * into invitation;
  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
  values (target_space_id, actor_id, target_user_id, 'member_invited');
  return invitation;
end;
$$;

create or replace function public.set_space_member_role(
  acting_user_id uuid,
  target_space_id bigint,
  target_user_id uuid,
  requested_role text
)
returns public.space_memberships
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  membership public.space_memberships%rowtype;
  old_role text;
begin
  if requested_role not in ('moderator', 'member') then
    raise exception using errcode = '22023', message = 'invalid_delegated_role';
  end if;
  if not exists (
    select 1 from public.space_memberships owner_membership
    where owner_membership.space_id = target_space_id
      and owner_membership.user_id = actor_id
      and owner_membership.role = 'owner'
      and owner_membership.status = 'active'
  ) then
    raise exception using errcode = '42501', message = 'space_owner_required';
  end if;
  select role into old_role from public.space_memberships
  where space_id = target_space_id and user_id = target_user_id and status = 'active'
  for update;
  if old_role is null or old_role = 'owner' then
    raise exception using errcode = '22023', message = 'invalid_role_target';
  end if;
  if not private.is_active_space_member(target_space_id, target_user_id) then
    raise exception using errcode = '42501', message = 'active_member_required';
  end if;
  update public.space_memberships
  set role = requested_role
  where space_id = target_space_id and user_id = target_user_id
  returning * into membership;
  if old_role <> requested_role then
    insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type, details)
    values (
      target_space_id, actor_id, target_user_id, 'member_role_changed',
      jsonb_build_object('from', old_role, 'to', requested_role)
    );
  end if;
  return membership;
end;
$$;

create or replace function public.transfer_space_ownership(
  acting_user_id uuid,
  target_space_id bigint,
  new_owner_id uuid
)
returns public.spaces
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  resulting_space public.spaces%rowtype;
begin
  perform 1 from public.spaces where id = target_space_id for update;
  if not exists (
    select 1 from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = actor_id
      and membership.role = 'owner'
      and membership.status = 'active'
  ) then
    raise exception using errcode = '42501', message = 'space_owner_required';
  end if;
  if actor_id = new_owner_id then
    select * into strict resulting_space from public.spaces where id = target_space_id;
    return resulting_space;
  end if;
  if not private.is_active_space_member(target_space_id, new_owner_id) then
    raise exception using errcode = '42501', message = 'eligible_new_owner_required';
  end if;

  update public.space_memberships set role = 'moderator'
  where space_id = target_space_id and user_id = actor_id;
  update public.space_memberships set role = 'owner'
  where space_id = target_space_id and user_id = new_owner_id;
  update public.spaces set owner_id = new_owner_id
  where id = target_space_id returning * into resulting_space;
  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type, details)
  values (
    target_space_id, actor_id, new_owner_id, 'ownership_transferred',
    jsonb_build_object('previous_owner_id', actor_id)
  );
  return resulting_space;
end;
$$;

create or replace function public.ban_space_member(
  acting_user_id uuid,
  target_space_id bigint,
  target_user_id uuid,
  ban_reason text,
  ban_expires_at timestamptz default null
)
returns public.space_bans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  actor_role text;
  target_role text;
  resulting_ban public.space_bans%rowtype;
begin
  select membership.role into actor_role
  from public.space_memberships membership
  where membership.space_id = target_space_id
    and membership.user_id = actor_id
    and membership.status = 'active';
  if actor_role not in ('owner', 'moderator') then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  select membership.role into target_role
  from public.space_memberships membership
  where membership.space_id = target_space_id
    and membership.user_id = target_user_id
    and membership.status = 'active';
  if target_role = 'owner' or (target_role = 'moderator' and actor_role <> 'owner') then
    raise exception using errcode = '42501', message = 'protected_space_role';
  end if;
  if actor_id = target_user_id then
    raise exception using errcode = '42501', message = 'cannot_ban_self';
  end if;

  insert into public.space_bans (space_id, user_id, banned_by, reason, expires_at)
  values (target_space_id, target_user_id, actor_id, btrim(ban_reason), ban_expires_at)
  on conflict (space_id, user_id) do update
  set
    banned_by = excluded.banned_by,
    reason = excluded.reason,
    expires_at = excluded.expires_at,
    created_at = statement_timestamp(),
    revoked_at = null,
    revoked_by = null
  returning * into resulting_ban;

  update public.space_memberships set status = 'left'
  where space_id = target_space_id and user_id = target_user_id and status = 'active';
  update public.space_join_requests
  set status = 'rejected', decided_by = actor_id, decided_at = statement_timestamp()
  where space_id = target_space_id and user_id = target_user_id and status = 'pending';
  update public.space_invitations
  set status = 'revoked', responded_at = statement_timestamp()
  where space_id = target_space_id and user_id = target_user_id and status = 'pending';
  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type, details)
  values (
    target_space_id, actor_id, target_user_id, 'member_banned',
    jsonb_build_object('expires_at', ban_expires_at)
  );
  return resulting_ban;
end;
$$;

create or replace function public.unban_space_member(
  acting_user_id uuid,
  target_space_id bigint,
  target_user_id uuid
)
returns public.space_bans
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  resulting_ban public.space_bans%rowtype;
begin
  if not private.is_space_moderator(target_space_id, actor_id) then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  update public.space_bans
  set revoked_at = statement_timestamp(), revoked_by = actor_id
  where space_id = target_space_id and user_id = target_user_id and revoked_at is null
  returning * into resulting_ban;
  if not found then
    raise exception using errcode = 'P0002', message = 'active_space_ban_not_found';
  end if;
  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type)
  values (target_space_id, actor_id, target_user_id, 'member_unbanned');
  return resulting_ban;
end;
$$;

create or replace function public.add_space_reputation(
  acting_user_id uuid,
  target_space_id bigint,
  target_user_id uuid,
  score_delta smallint,
  change_reason text,
  request_key uuid
)
returns public.space_reputation_entries
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  entry public.space_reputation_entries%rowtype;
begin
  if not private.is_space_moderator(target_space_id, actor_id) then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  if not private.is_active_space_member(target_space_id, target_user_id) then
    raise exception using errcode = '42501', message = 'active_member_required';
  end if;
  insert into public.space_reputation_entries (
    space_id, user_id, actor_id, delta, reason, idempotency_key
  ) values (
    target_space_id, target_user_id, actor_id, score_delta, btrim(change_reason), request_key
  )
  on conflict (space_id, idempotency_key) do nothing
  returning * into entry;
  if entry.id is null then
    select * into strict entry
    from public.space_reputation_entries existing
    where existing.space_id = target_space_id and existing.idempotency_key = request_key;
    if entry.user_id <> target_user_id
      or entry.actor_id <> actor_id
      or entry.delta <> score_delta
      or entry.reason <> btrim(change_reason) then
      raise exception using errcode = '22023', message = 'idempotency_key_payload_mismatch';
    end if;
    return entry;
  end if;
  insert into public.space_audit_events (space_id, actor_id, subject_user_id, event_type, details)
  values (
    target_space_id, actor_id, target_user_id, 'reputation_changed',
    jsonb_build_object('entry_id', entry.id, 'delta', score_delta)
  );
  return entry;
end;
$$;

create or replace function public.upsert_space_rule(
  acting_user_id uuid,
  target_space_id bigint,
  target_rule_id bigint,
  requested_position smallint,
  requested_title text,
  requested_body text,
  requested_is_required boolean default true
)
returns public.space_rules
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  resulting_rule public.space_rules%rowtype;
begin
  if not private.is_space_moderator(target_space_id, actor_id) then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  if target_rule_id is null then
    insert into public.space_rules (space_id, position, title, body, is_required)
    values (
      target_space_id, requested_position, btrim(requested_title), btrim(requested_body), requested_is_required
    ) returning * into resulting_rule;
  else
    update public.space_rules
    set
      position = requested_position,
      title = btrim(requested_title),
      body = btrim(requested_body),
      is_required = requested_is_required
    where id = target_rule_id and space_id = target_space_id
    returning * into resulting_rule;
    if not found then
      raise exception using errcode = 'P0002', message = 'space_rule_not_found';
    end if;
  end if;
  insert into public.space_audit_events (space_id, actor_id, event_type, details)
  values (target_space_id, actor_id, 'rule_upserted', jsonb_build_object('rule_id', resulting_rule.id));
  return resulting_rule;
end;
$$;

create or replace function public.remove_space_rule(
  acting_user_id uuid,
  target_space_id bigint,
  target_rule_id bigint
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
begin
  if not private.is_space_moderator(target_space_id, actor_id) then
    raise exception using errcode = '42501', message = 'space_moderator_required';
  end if;
  delete from public.space_rules where id = target_rule_id and space_id = target_space_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'space_rule_not_found';
  end if;
  insert into public.space_audit_events (space_id, actor_id, event_type, details)
  values (target_space_id, actor_id, 'rule_removed', jsonb_build_object('rule_id', target_rule_id));
end;
$$;

revoke execute on function public.create_space(uuid, text, text, text, text, text)
from public, anon, authenticated;
revoke execute on function public.join_space(uuid, bigint) from public, anon, authenticated;
revoke execute on function public.leave_space(uuid, bigint) from public, anon, authenticated;
revoke execute on function public.review_space_join_request(uuid, bigint, text)
from public, anon, authenticated;
revoke execute on function public.invite_space_member(uuid, bigint, uuid, timestamptz)
from public, anon, authenticated;
revoke execute on function public.set_space_member_role(uuid, bigint, uuid, text)
from public, anon, authenticated;
revoke execute on function public.transfer_space_ownership(uuid, bigint, uuid)
from public, anon, authenticated;
revoke execute on function public.ban_space_member(uuid, bigint, uuid, text, timestamptz)
from public, anon, authenticated;
revoke execute on function public.unban_space_member(uuid, bigint, uuid)
from public, anon, authenticated;
revoke execute on function public.add_space_reputation(uuid, bigint, uuid, smallint, text, uuid)
from public, anon, authenticated;
revoke execute on function public.upsert_space_rule(uuid, bigint, bigint, smallint, text, text, boolean)
from public, anon, authenticated;
revoke execute on function public.remove_space_rule(uuid, bigint, bigint)
from public, anon, authenticated;

grant execute on function public.create_space(uuid, text, text, text, text, text) to service_role;
grant execute on function public.join_space(uuid, bigint) to service_role;
grant execute on function public.leave_space(uuid, bigint) to service_role;
grant execute on function public.review_space_join_request(uuid, bigint, text) to service_role;
grant execute on function public.invite_space_member(uuid, bigint, uuid, timestamptz) to service_role;
grant execute on function public.set_space_member_role(uuid, bigint, uuid, text) to service_role;
grant execute on function public.transfer_space_ownership(uuid, bigint, uuid) to service_role;
grant execute on function public.ban_space_member(uuid, bigint, uuid, text, timestamptz) to service_role;
grant execute on function public.unban_space_member(uuid, bigint, uuid) to service_role;
grant execute on function public.add_space_reputation(uuid, bigint, uuid, smallint, text, uuid)
to service_role;
grant execute on function public.upsert_space_rule(uuid, bigint, bigint, smallint, text, text, boolean)
to service_role;
grant execute on function public.remove_space_rule(uuid, bigint, bigint) to service_role;
