-- Phase 3: content primitives, media ownership, idempotency, and abuse-resistant mutations.

create table public.content_posts (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  author_id uuid not null references public.profiles(user_id) on delete restrict,
  kind text not null check (kind in ('text', 'image', 'link', 'poll', 'question')),
  visibility text not null default 'space' check (visibility in ('space', 'members')),
  body text not null default '',
  link_url text,
  status text not null default 'published' check (status in ('published', 'deleted', 'removed')),
  edited_at timestamptz,
  deleted_at timestamptz,
  removed_by uuid references public.profiles(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint content_posts_body_length check (char_length(body) between 0 and 10000),
  constraint content_posts_published_body check (
    status <> 'published'
    or kind = 'image'
    or char_length(btrim(body)) between 1 and 10000
  ),
  constraint content_posts_link_shape check (
    (kind = 'link' and link_url ~ '^https://[^[:space:]]+$')
    or (kind <> 'link' and link_url is null)
  ),
  constraint content_posts_removal_actor check (
    (status = 'removed' and removed_by is not null)
    or (status <> 'removed' and removed_by is null)
  )
);

create index content_posts_space_created_idx
on public.content_posts (space_id, created_at desc, id desc)
where status = 'published';

create index content_posts_author_created_idx
on public.content_posts (author_id, created_at desc, id desc);

create table public.content_post_revisions (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.content_posts(id) on delete cascade,
  revision_number integer not null check (revision_number > 0),
  editor_id uuid not null references public.profiles(user_id) on delete restrict,
  body text not null,
  link_url text,
  visibility text not null check (visibility in ('space', 'members')),
  recorded_at timestamptz not null default statement_timestamp(),
  unique (post_id, revision_number)
);

create index content_post_revisions_post_idx
on public.content_post_revisions (post_id, revision_number desc);

create table public.content_media_assets (
  id uuid primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  owner_id uuid not null references public.profiles(user_id) on delete restrict,
  post_id bigint references public.content_posts(id) on delete set null,
  object_path text not null unique,
  original_filename text not null,
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/gif')),
  byte_size bigint not null check (byte_size between 1 and 5242880),
  position smallint not null default 1 check (position between 1 and 4),
  status text not null default 'staged' check (status in ('staged', 'attached', 'deleted')),
  created_at timestamptz not null default statement_timestamp(),
  attached_at timestamptz,
  constraint content_media_asset_path check (
    object_path = owner_id::text || '/' || id::text || '/' || original_filename
    and original_filename ~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$'
  ),
  constraint content_media_attachment_shape check (
    (status = 'staged' and post_id is null and attached_at is null)
    or (status = 'attached' and post_id is not null and attached_at is not null)
    or status = 'deleted'
  ),
  unique (post_id, position)
);

create index content_media_assets_owner_status_idx
on public.content_media_assets (owner_id, status, created_at desc);

create index content_media_assets_post_idx
on public.content_media_assets (post_id)
where post_id is not null;

create table public.content_polls (
  post_id bigint primary key references public.content_posts(id) on delete cascade,
  allows_multiple boolean not null default false,
  ends_at timestamptz,
  created_at timestamptz not null default statement_timestamp()
);

create table public.content_poll_options (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.content_polls(post_id) on delete cascade,
  position smallint not null check (position between 1 and 10),
  label text not null check (char_length(btrim(label)) between 1 and 120),
  vote_count integer not null default 0 check (vote_count >= 0),
  unique (post_id, position),
  unique (post_id, id)
);

create index content_poll_options_post_idx
on public.content_poll_options (post_id, position);

create table public.content_poll_votes (
  post_id bigint not null references public.content_polls(post_id) on delete cascade,
  option_id bigint not null,
  voter_id uuid not null references public.profiles(user_id) on delete cascade,
  created_at timestamptz not null default statement_timestamp(),
  primary key (option_id, voter_id),
  foreign key (post_id, option_id)
    references public.content_poll_options(post_id, id) on delete cascade
);

create index content_poll_votes_voter_post_idx
on public.content_poll_votes (voter_id, post_id);

create table public.content_replies (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.content_posts(id) on delete cascade,
  author_id uuid not null references public.profiles(user_id) on delete restrict,
  parent_reply_id bigint references public.content_replies(id) on delete set null,
  body text not null check (char_length(btrim(body)) between 1 and 5000),
  status text not null default 'published' check (status in ('published', 'deleted', 'removed')),
  edited_at timestamptz,
  deleted_at timestamptz,
  removed_by uuid references public.profiles(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint content_replies_removal_actor check (
    (status = 'removed' and removed_by is not null)
    or (status <> 'removed' and removed_by is null)
  )
);

create index content_replies_post_created_idx
on public.content_replies (post_id, created_at, id);

create index content_replies_parent_idx
on public.content_replies (parent_reply_id)
where parent_reply_id is not null;

create table public.content_reply_revisions (
  id bigint generated always as identity primary key,
  reply_id bigint not null references public.content_replies(id) on delete cascade,
  revision_number integer not null check (revision_number > 0),
  editor_id uuid not null references public.profiles(user_id) on delete restrict,
  body text not null,
  recorded_at timestamptz not null default statement_timestamp(),
  unique (reply_id, revision_number)
);

create table public.content_questions (
  post_id bigint primary key references public.content_posts(id) on delete cascade,
  accepted_reply_id bigint references public.content_replies(id) on delete set null,
  accepted_by uuid references public.profiles(user_id) on delete restrict,
  accepted_at timestamptz,
  constraint content_question_acceptance_shape check (
    (accepted_reply_id is null and accepted_by is null and accepted_at is null)
    or (accepted_reply_id is not null and accepted_by is not null and accepted_at is not null)
  )
);

create table public.content_mentions (
  id bigint generated always as identity primary key,
  post_id bigint references public.content_posts(id) on delete cascade,
  reply_id bigint references public.content_replies(id) on delete cascade,
  mentioned_user_id uuid not null references public.profiles(user_id) on delete cascade,
  created_by uuid not null references public.profiles(user_id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  constraint content_mentions_one_target check (num_nonnulls(post_id, reply_id) = 1)
);

create unique index content_mentions_post_user_unique
on public.content_mentions (post_id, mentioned_user_id)
where post_id is not null;

create unique index content_mentions_reply_user_unique
on public.content_mentions (reply_id, mentioned_user_id)
where reply_id is not null;

create index content_mentions_user_created_idx
on public.content_mentions (mentioned_user_id, created_at desc);

create table public.content_reactions (
  id bigint generated always as identity primary key,
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  post_id bigint references public.content_posts(id) on delete cascade,
  reply_id bigint references public.content_replies(id) on delete cascade,
  reaction text not null check (reaction in ('apresiasi', 'membantu', 'menarik')),
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint content_reactions_one_target check (num_nonnulls(post_id, reply_id) = 1)
);

create unique index content_reactions_post_actor_unique
on public.content_reactions (post_id, actor_id)
where post_id is not null;

create unique index content_reactions_reply_actor_unique
on public.content_reactions (reply_id, actor_id)
where reply_id is not null;

create index content_reactions_post_idx on public.content_reactions (post_id)
where post_id is not null;
create index content_reactions_reply_idx on public.content_reactions (reply_id)
where reply_id is not null;

create table public.content_saves (
  user_id uuid not null references public.profiles(user_id) on delete cascade,
  post_id bigint not null references public.content_posts(id) on delete cascade,
  created_at timestamptz not null default statement_timestamp(),
  primary key (user_id, post_id)
);

create index content_saves_post_idx on public.content_saves (post_id);

create table public.content_mutation_requests (
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  request_key uuid not null,
  operation text not null,
  result jsonb not null,
  completed_at timestamptz not null default statement_timestamp(),
  primary key (actor_id, request_key)
);

create index content_mutation_requests_completed_idx
on public.content_mutation_requests (completed_at);

create table public.content_rate_events (
  id bigint generated always as identity primary key,
  actor_id uuid not null references public.profiles(user_id) on delete cascade,
  operation text not null,
  occurred_at timestamptz not null default clock_timestamp()
);

create index content_rate_events_actor_operation_idx
on public.content_rate_events (actor_id, operation, occurred_at desc);

create table public.content_audit_events (
  id bigint generated always as identity primary key,
  space_id bigint not null references public.spaces(id) on delete cascade,
  actor_id uuid not null references public.profiles(user_id) on delete restrict,
  post_id bigint references public.content_posts(id) on delete set null,
  reply_id bigint references public.content_replies(id) on delete set null,
  event_type text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  constraint content_audit_event_target check (reply_id is null or post_id is not null)
);

create index content_audit_events_space_created_idx
on public.content_audit_events (space_id, created_at desc);

create index content_audit_events_post_idx on public.content_audit_events (post_id)
where post_id is not null;

create index content_audit_events_actor_idx on public.content_audit_events (actor_id);
create index content_audit_events_reply_idx on public.content_audit_events (reply_id)
where reply_id is not null;
create index content_media_assets_space_idx on public.content_media_assets (space_id);
create index content_mentions_created_by_idx on public.content_mentions (created_by);
create index content_poll_votes_post_option_idx on public.content_poll_votes (post_id, option_id);
create index content_post_revisions_editor_idx on public.content_post_revisions (editor_id);
create index content_posts_removed_by_idx on public.content_posts (removed_by)
where removed_by is not null;
create index content_questions_accepted_by_idx on public.content_questions (accepted_by)
where accepted_by is not null;
create index content_questions_accepted_reply_idx on public.content_questions (accepted_reply_id)
where accepted_reply_id is not null;
create index content_reactions_actor_idx on public.content_reactions (actor_id);
create index content_replies_author_idx on public.content_replies (author_id);
create index content_replies_removed_by_idx on public.content_replies (removed_by)
where removed_by is not null;
create index content_reply_revisions_editor_idx on public.content_reply_revisions (editor_id);

create trigger content_posts_set_updated_at
before update on public.content_posts
for each row execute function private.set_updated_at();

create trigger content_replies_set_updated_at
before update on public.content_replies
for each row execute function private.set_updated_at();

create trigger content_reactions_set_updated_at
before update on public.content_reactions
for each row execute function private.set_updated_at();

create or replace function private.can_view_content_post(target_post_id bigint, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.content_posts post
    join public.spaces space on space.id = post.space_id
    where post.id = target_post_id
      and (
        post.author_id = target_user_id
        or private.is_space_moderator(post.space_id, target_user_id)
        or (
          post.status = 'published'
          and space.lifecycle = 'active'
          and (
            private.is_active_space_member(post.space_id, target_user_id)
            or (
              post.visibility = 'space'
              and space.discoverability in ('public', 'unlisted')
            )
          )
        )
      )
  );
$$;

create or replace function private.can_view_content_reply(target_reply_id bigint, target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.content_replies reply
    where reply.id = target_reply_id
      and (
        reply.author_id = target_user_id
        or private.is_space_moderator(
          (select post.space_id from public.content_posts post where post.id = reply.post_id),
          target_user_id
        )
        or (
          reply.status = 'published'
          and private.can_view_content_post(reply.post_id, target_user_id)
        )
      )
  );
$$;

create or replace function private.capture_content_post_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (old.body, old.link_url, old.visibility) is distinct from
     (new.body, new.link_url, new.visibility) then
    insert into public.content_post_revisions (
      post_id, revision_number, editor_id, body, link_url, visibility
    )
    values (
      old.id,
      coalesce((select max(revision.revision_number) + 1
                from public.content_post_revisions revision
                where revision.post_id = old.id), 1),
      coalesce(new.author_id, old.author_id),
      old.body,
      old.link_url,
      old.visibility
    );
  end if;
  return new;
end;
$$;

create or replace function private.capture_content_reply_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.body is distinct from new.body then
    insert into public.content_reply_revisions (reply_id, revision_number, editor_id, body)
    values (
      old.id,
      coalesce((select max(revision.revision_number) + 1
                from public.content_reply_revisions revision
                where revision.reply_id = old.id), 1),
      coalesce(new.author_id, old.author_id),
      old.body
    );
  end if;
  return new;
end;
$$;

create trigger content_posts_capture_revision
before update on public.content_posts
for each row execute function private.capture_content_post_revision();

create trigger content_replies_capture_revision
before update on public.content_replies
for each row execute function private.capture_content_reply_revision();

create or replace function private.begin_content_mutation(
  target_actor_id uuid,
  target_request_key uuid,
  target_operation text,
  maximum_events integer,
  event_window interval
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  existing_operation text;
  existing_result jsonb;
  recent_events integer;
begin
  if target_actor_id is null or target_request_key is null then
    raise exception using errcode = '22023', message = 'mutation_identity_required';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_actor_id::text || ':' || target_request_key::text, 0)
  );

  select request.operation, request.result
  into existing_operation, existing_result
  from public.content_mutation_requests request
  where request.actor_id = target_actor_id
    and request.request_key = target_request_key;

  if found then
    if existing_operation <> target_operation then
      raise exception using errcode = '22023', message = 'idempotency_key_operation_mismatch';
    end if;
    return existing_result;
  end if;

  select count(*)::integer into recent_events
  from public.content_rate_events event
  where event.actor_id = target_actor_id
    and event.operation = target_operation
    and event.occurred_at >= clock_timestamp() - event_window;
  if recent_events >= maximum_events then
    raise exception using errcode = '54000', message = 'content_rate_limit_exceeded';
  end if;
  insert into public.content_rate_events (actor_id, operation)
  values (target_actor_id, target_operation);
  return null;
end;
$$;

create or replace function private.complete_content_mutation(
  target_actor_id uuid,
  target_request_key uuid,
  target_operation text,
  mutation_result jsonb
)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into public.content_mutation_requests (actor_id, request_key, operation, result)
  values (target_actor_id, target_request_key, target_operation, mutation_result);
$$;

create or replace function private.assert_content_actor(target_actor_id uuid, target_space_id bigint)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if target_actor_id is null then
    raise exception using errcode = '28000', message = 'authentication_required';
  end if;
  if not exists (
    select 1 from public.identity_accounts account
    where account.user_id = target_actor_id
      and account.onboarding_completed_at is not null
  ) then
    raise exception using errcode = '42501', message = 'onboarding_required';
  end if;
  if not private.is_active_space_member(target_space_id, target_actor_id) then
    raise exception using errcode = '42501', message = 'active_space_membership_required';
  end if;
end;
$$;

create or replace function private.replace_content_mentions(
  target_actor_id uuid,
  target_space_id bigint,
  target_post_id bigint,
  target_reply_id bigint,
  mentioned_user_ids uuid[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  mentioned_user_id uuid;
begin
  if target_post_id is not null then
    delete from public.content_mentions mention where mention.post_id = target_post_id;
  else
    delete from public.content_mentions mention where mention.reply_id = target_reply_id;
  end if;

  foreach mentioned_user_id in array coalesce(mentioned_user_ids, array[]::uuid[]) loop
    if mentioned_user_id = target_actor_id then
      continue;
    end if;
    if not private.is_active_space_member(target_space_id, mentioned_user_id) then
      raise exception using errcode = '22023', message = 'mentioned_user_not_space_member';
    end if;
    insert into public.content_mentions (post_id, reply_id, mentioned_user_id, created_by)
    values (target_post_id, target_reply_id, mentioned_user_id, target_actor_id)
    on conflict do nothing;
  end loop;
end;
$$;

revoke execute on function private.can_view_content_post(bigint, uuid) from public, anon;
revoke execute on function private.can_view_content_reply(bigint, uuid) from public, anon;
revoke execute on function private.capture_content_post_revision() from public, anon, authenticated;
revoke execute on function private.capture_content_reply_revision() from public, anon, authenticated;
revoke execute on function private.begin_content_mutation(uuid, uuid, text, integer, interval)
  from public, anon, authenticated;
revoke execute on function private.complete_content_mutation(uuid, uuid, text, jsonb)
  from public, anon, authenticated;
revoke execute on function private.assert_content_actor(uuid, bigint) from public, anon, authenticated;
revoke execute on function private.replace_content_mentions(uuid, bigint, bigint, bigint, uuid[])
  from public, anon, authenticated;

grant execute on function private.can_view_content_post(bigint, uuid) to authenticated, service_role;
grant execute on function private.can_view_content_reply(bigint, uuid) to authenticated, service_role;
grant execute on function private.capture_content_post_revision() to service_role;
grant execute on function private.capture_content_reply_revision() to service_role;
grant execute on function private.begin_content_mutation(uuid, uuid, text, integer, interval)
  to service_role;
grant execute on function private.complete_content_mutation(uuid, uuid, text, jsonb)
  to service_role;
grant execute on function private.assert_content_actor(uuid, bigint) to service_role;
grant execute on function private.replace_content_mentions(uuid, bigint, bigint, bigint, uuid[])
  to service_role;

alter table public.content_posts enable row level security;
alter table public.content_posts force row level security;
alter table public.content_post_revisions enable row level security;
alter table public.content_post_revisions force row level security;
alter table public.content_media_assets enable row level security;
alter table public.content_media_assets force row level security;
alter table public.content_polls enable row level security;
alter table public.content_polls force row level security;
alter table public.content_poll_options enable row level security;
alter table public.content_poll_options force row level security;
alter table public.content_poll_votes enable row level security;
alter table public.content_poll_votes force row level security;
alter table public.content_replies enable row level security;
alter table public.content_replies force row level security;
alter table public.content_reply_revisions enable row level security;
alter table public.content_reply_revisions force row level security;
alter table public.content_questions enable row level security;
alter table public.content_questions force row level security;
alter table public.content_mentions enable row level security;
alter table public.content_mentions force row level security;
alter table public.content_reactions enable row level security;
alter table public.content_reactions force row level security;
alter table public.content_saves enable row level security;
alter table public.content_saves force row level security;
alter table public.content_mutation_requests enable row level security;
alter table public.content_mutation_requests force row level security;
alter table public.content_rate_events enable row level security;
alter table public.content_rate_events force row level security;
alter table public.content_audit_events enable row level security;
alter table public.content_audit_events force row level security;

revoke all on table public.content_posts, public.content_post_revisions,
  public.content_media_assets, public.content_polls, public.content_poll_options,
  public.content_poll_votes, public.content_replies, public.content_reply_revisions,
  public.content_questions, public.content_mentions, public.content_reactions,
  public.content_saves, public.content_mutation_requests, public.content_rate_events,
  public.content_audit_events
from public, anon, authenticated;

grant select on table public.content_posts, public.content_post_revisions,
  public.content_media_assets, public.content_polls, public.content_poll_options,
  public.content_poll_votes, public.content_replies, public.content_reply_revisions,
  public.content_questions, public.content_mentions, public.content_reactions,
  public.content_saves, public.content_audit_events
to authenticated;

grant all on table public.content_posts, public.content_post_revisions,
  public.content_media_assets, public.content_polls, public.content_poll_options,
  public.content_poll_votes, public.content_replies, public.content_reply_revisions,
  public.content_questions, public.content_mentions, public.content_reactions,
  public.content_saves, public.content_mutation_requests, public.content_rate_events,
  public.content_audit_events
to service_role;

grant usage, select on all sequences in schema public to service_role;

create policy content_posts_visible_select
on public.content_posts
for select
to authenticated
using ((select private.can_view_content_post(id, (select auth.uid()))));

create policy content_post_revisions_visible_select
on public.content_post_revisions
for select
to authenticated
using ((select private.can_view_content_post(post_id, (select auth.uid()))));

create policy content_media_assets_visible_select
on public.content_media_assets
for select
to authenticated
using (
  owner_id = (select auth.uid())
  or (
    status = 'attached'
    and (select private.can_view_content_post(post_id, (select auth.uid())))
  )
);

create policy content_polls_visible_select
on public.content_polls
for select
to authenticated
using ((select private.can_view_content_post(post_id, (select auth.uid()))));

create policy content_poll_options_visible_select
on public.content_poll_options
for select
to authenticated
using ((select private.can_view_content_post(post_id, (select auth.uid()))));

create policy content_poll_votes_subject_or_moderator_select
on public.content_poll_votes
for select
to authenticated
using (
  voter_id = (select auth.uid())
  or exists (
    select 1 from public.content_posts post
    where post.id = content_poll_votes.post_id
      and (select private.is_space_moderator(post.space_id, (select auth.uid())))
  )
);

create policy content_replies_visible_select
on public.content_replies
for select
to authenticated
using ((select private.can_view_content_reply(id, (select auth.uid()))));

create policy content_reply_revisions_visible_select
on public.content_reply_revisions
for select
to authenticated
using ((select private.can_view_content_reply(reply_id, (select auth.uid()))));

create policy content_questions_visible_select
on public.content_questions
for select
to authenticated
using ((select private.can_view_content_post(post_id, (select auth.uid()))));

create policy content_mentions_visible_select
on public.content_mentions
for select
to authenticated
using (
  mentioned_user_id = (select auth.uid())
  or (post_id is not null and (select private.can_view_content_post(post_id, (select auth.uid()))))
  or (reply_id is not null and (select private.can_view_content_reply(reply_id, (select auth.uid()))))
);

create policy content_reactions_visible_select
on public.content_reactions
for select
to authenticated
using (
  (post_id is not null and (select private.can_view_content_post(post_id, (select auth.uid()))))
  or (reply_id is not null and (select private.can_view_content_reply(reply_id, (select auth.uid()))))
);

create policy content_saves_owner_select
on public.content_saves
for select
to authenticated
using (user_id = (select auth.uid()));

create policy content_mutation_requests_explicit_deny
on public.content_mutation_requests
for select
to authenticated
using (false);

create policy content_rate_events_explicit_deny
on public.content_rate_events
for select
to authenticated
using (false);

create policy content_audit_events_actor_or_moderator_select
on public.content_audit_events
for select
to authenticated
using (
  actor_id = (select auth.uid())
  or (select private.is_space_moderator(space_id, (select auth.uid())))
);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'content-media',
  'content-media',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy content_media_objects_read
on storage.objects
for select
to authenticated
using (
  bucket_id = 'content-media'
  and exists (
    select 1
    from public.content_media_assets asset
    where asset.object_path = storage.objects.name
      and (
        asset.owner_id = (select auth.uid())
        or (
          asset.status = 'attached'
          and (select private.can_view_content_post(asset.post_id, (select auth.uid())))
        )
      )
  )
);

create policy content_media_objects_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'content-media'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (
    select 1
    from public.content_media_assets asset
    where asset.object_path = storage.objects.name
      and asset.owner_id = (select auth.uid())
      and asset.status = 'staged'
  )
);

create policy content_media_objects_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'content-media'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1 from public.content_media_assets asset
    where asset.object_path = storage.objects.name
      and asset.owner_id = (select auth.uid())
      and asset.status = 'staged'
  )
)
with check (
  bucket_id = 'content-media'
  and owner_id = (select auth.uid())::text
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy content_media_objects_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'content-media'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1 from public.content_media_assets asset
    where asset.object_path = storage.objects.name
      and asset.owner_id = (select auth.uid())
      and asset.status = 'staged'
  )
);

create or replace function public.register_content_media(
  acting_user_id uuid,
  target_space_id bigint,
  requested_asset_id uuid,
  requested_filename text,
  requested_mime_type text,
  requested_byte_size bigint,
  request_key uuid
)
returns public.content_media_assets
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'register_media';
  existing_result jsonb;
  normalized_filename text := btrim(requested_filename);
  created_asset public.content_media_assets%rowtype;
begin
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 20, interval '10 minutes'
  );
  if existing_result is not null then
    select * into strict created_asset
    from public.content_media_assets asset
    where asset.id = (existing_result->>'asset_id')::uuid;
    return created_asset;
  end if;
  if requested_asset_id is null
     or normalized_filename !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,119}$'
     or requested_mime_type not in ('image/jpeg', 'image/png', 'image/webp', 'image/gif')
     or requested_byte_size not between 1 and 5242880 then
    raise exception using errcode = '22023', message = 'invalid_media_metadata';
  end if;

  insert into public.content_media_assets (
    id, space_id, owner_id, object_path, original_filename, mime_type, byte_size
  )
  values (
    requested_asset_id,
    target_space_id,
    actor_id,
    actor_id::text || '/' || requested_asset_id::text || '/' || normalized_filename,
    normalized_filename,
    requested_mime_type,
    requested_byte_size
  )
  returning * into created_asset;

  perform private.complete_content_mutation(
    actor_id, request_key, operation_name,
    jsonb_build_object('asset_id', created_asset.id, 'object_path', created_asset.object_path)
  );
  return created_asset;
end;
$$;

create or replace function public.create_content_post(
  acting_user_id uuid,
  target_space_id bigint,
  requested_kind text,
  requested_visibility text,
  requested_body text,
  requested_link_url text,
  requested_poll_options text[],
  requested_poll_allows_multiple boolean,
  requested_poll_ends_at timestamptz,
  requested_media_asset_ids uuid[],
  mentioned_user_ids uuid[],
  request_key uuid
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'create_post';
  existing_result jsonb;
  normalized_body text := btrim(coalesce(requested_body, ''));
  normalized_link_url text := nullif(btrim(coalesce(requested_link_url, '')), '');
  created_post_id bigint;
  option_label text;
  option_position integer := 0;
  attached_count integer;
begin
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 10, interval '10 minutes'
  );
  if existing_result is not null then
    return (existing_result->>'post_id')::bigint;
  end if;

  if requested_kind not in ('text', 'image', 'link', 'poll', 'question')
     or requested_visibility not in ('space', 'members') then
    raise exception using errcode = '22023', message = 'invalid_content_post_type';
  end if;
  if char_length(normalized_body) > 10000
     or (requested_kind <> 'image' and char_length(normalized_body) < 1) then
    raise exception using errcode = '22023', message = 'invalid_content_body';
  end if;
  if requested_kind = 'link' then
    if normalized_link_url is null or normalized_link_url !~ '^https://[^[:space:]]+$' then
      raise exception using errcode = '22023', message = 'invalid_content_link';
    end if;
  elsif normalized_link_url is not null then
    raise exception using errcode = '22023', message = 'unexpected_content_link';
  end if;

  if requested_kind = 'poll' then
    if cardinality(coalesce(requested_poll_options, array[]::text[])) not between 2 and 10
       or (requested_poll_ends_at is not null and requested_poll_ends_at <= statement_timestamp()) then
      raise exception using errcode = '22023', message = 'invalid_content_poll';
    end if;
  elsif cardinality(coalesce(requested_poll_options, array[]::text[])) <> 0
        or coalesce(requested_poll_allows_multiple, false)
        or requested_poll_ends_at is not null then
    raise exception using errcode = '22023', message = 'unexpected_content_poll';
  end if;

  if requested_kind = 'image' then
    if cardinality(coalesce(requested_media_asset_ids, array[]::uuid[])) not between 1 and 4 then
      raise exception using errcode = '22023', message = 'content_image_required';
    end if;
  elsif cardinality(coalesce(requested_media_asset_ids, array[]::uuid[])) <> 0 then
    raise exception using errcode = '22023', message = 'unexpected_content_media';
  end if;

  insert into public.content_posts (
    space_id, author_id, kind, visibility, body, link_url
  )
  values (
    target_space_id, actor_id, requested_kind, requested_visibility,
    normalized_body, normalized_link_url
  )
  returning id into created_post_id;

  if requested_kind = 'poll' then
    insert into public.content_polls (post_id, allows_multiple, ends_at)
    values (created_post_id, coalesce(requested_poll_allows_multiple, false), requested_poll_ends_at);
    foreach option_label in array requested_poll_options loop
      option_position := option_position + 1;
      if char_length(btrim(option_label)) not between 1 and 120 then
        raise exception using errcode = '22023', message = 'invalid_content_poll_option';
      end if;
      insert into public.content_poll_options (post_id, position, label)
      values (created_post_id, option_position, btrim(option_label));
    end loop;
  elsif requested_kind = 'question' then
    insert into public.content_questions (post_id) values (created_post_id);
  elsif requested_kind = 'image' then
    with requested_assets as (
      select asset_id, ordinal::smallint as position
      from unnest(requested_media_asset_ids) with ordinality as asset(asset_id, ordinal)
    )
    update public.content_media_assets asset
    set
      post_id = created_post_id,
      position = requested.position,
      status = 'attached',
      attached_at = statement_timestamp()
    from requested_assets requested
    where asset.id = requested.asset_id
      and asset.space_id = target_space_id
      and asset.owner_id = actor_id
      and asset.status = 'staged';
    get diagnostics attached_count = row_count;
    if attached_count <> cardinality(requested_media_asset_ids) then
      raise exception using errcode = '22023', message = 'invalid_or_owned_content_media';
    end if;
  end if;

  perform private.replace_content_mentions(
    actor_id, target_space_id, created_post_id, null, mentioned_user_ids
  );
  insert into public.content_audit_events (space_id, actor_id, post_id, event_type, details)
  values (
    target_space_id, actor_id, created_post_id, 'post_created',
    jsonb_build_object('kind', requested_kind, 'visibility', requested_visibility)
  );
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('post_id', created_post_id)
  );
  return created_post_id;
end;
$$;

create or replace function public.edit_content_post(
  acting_user_id uuid,
  target_post_id bigint,
  requested_visibility text,
  requested_body text,
  requested_link_url text,
  mentioned_user_ids uuid[],
  request_key uuid
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'edit_post';
  existing_result jsonb;
  target_post public.content_posts%rowtype;
  normalized_body text := btrim(coalesce(requested_body, ''));
  normalized_link_url text := nullif(btrim(coalesce(requested_link_url, '')), '');
begin
  select * into strict target_post from public.content_posts post where post.id = target_post_id for update;
  perform private.assert_content_actor(actor_id, target_post.space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 20, interval '10 minutes'
  );
  if existing_result is not null then
    return (existing_result->>'post_id')::bigint;
  end if;
  if target_post.author_id <> actor_id or target_post.status <> 'published' then
    raise exception using errcode = '42501', message = 'content_post_author_required';
  end if;
  if requested_visibility not in ('space', 'members')
     or char_length(normalized_body) > 10000
     or (target_post.kind <> 'image' and char_length(normalized_body) < 1) then
    raise exception using errcode = '22023', message = 'invalid_content_post_edit';
  end if;
  if target_post.kind = 'link' then
    if normalized_link_url is null or normalized_link_url !~ '^https://[^[:space:]]+$' then
      raise exception using errcode = '22023', message = 'invalid_content_link';
    end if;
  elsif normalized_link_url is not null then
    raise exception using errcode = '22023', message = 'unexpected_content_link';
  end if;

  update public.content_posts
  set
    visibility = requested_visibility,
    body = normalized_body,
    link_url = normalized_link_url,
    edited_at = statement_timestamp()
  where id = target_post_id;
  perform private.replace_content_mentions(
    actor_id, target_post.space_id, target_post_id, null, mentioned_user_ids
  );
  insert into public.content_audit_events (space_id, actor_id, post_id, event_type)
  values (target_post.space_id, actor_id, target_post_id, 'post_edited');
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('post_id', target_post_id)
  );
  return target_post_id;
end;
$$;

create or replace function public.delete_content_post(
  acting_user_id uuid,
  target_post_id bigint,
  request_key uuid
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'delete_post';
  existing_result jsonb;
  target_post public.content_posts%rowtype;
  resulting_status text;
  actor_role text;
  author_role text;
begin
  select * into strict target_post from public.content_posts post where post.id = target_post_id for update;
  perform private.assert_content_actor(actor_id, target_post.space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 10, interval '10 minutes'
  );
  if existing_result is not null then
    return existing_result->>'status';
  end if;
  if target_post.status <> 'published' then
    raise exception using errcode = '55000', message = 'content_post_not_published';
  end if;
  if target_post.author_id = actor_id then
    resulting_status := 'deleted';
  elsif private.is_space_moderator(target_post.space_id, actor_id) then
    select membership.role into actor_role
    from public.space_memberships membership
    where membership.space_id = target_post.space_id
      and membership.user_id = actor_id
      and membership.status = 'active';
    select membership.role into author_role
    from public.space_memberships membership
    where membership.space_id = target_post.space_id
      and membership.user_id = target_post.author_id
      and membership.status = 'active';
    if actor_role = 'moderator' and author_role in ('owner', 'moderator') then
      raise exception using errcode = '42501', message = 'protected_content_author_role';
    end if;
    resulting_status := 'removed';
  else
    raise exception using errcode = '42501', message = 'content_post_delete_forbidden';
  end if;

  update public.content_posts
  set
    status = resulting_status,
    deleted_at = statement_timestamp(),
    removed_by = case when resulting_status = 'removed' then actor_id else null end
  where id = target_post_id;
  insert into public.content_audit_events (space_id, actor_id, post_id, event_type)
  values (
    target_post.space_id, actor_id, target_post_id,
    case when resulting_status = 'removed' then 'post_removed' else 'post_deleted' end
  );
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('status', resulting_status)
  );
  return resulting_status;
end;
$$;

create or replace function public.create_content_reply(
  acting_user_id uuid,
  target_post_id bigint,
  target_parent_reply_id bigint,
  requested_body text,
  mentioned_user_ids uuid[],
  request_key uuid
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'create_reply';
  existing_result jsonb;
  target_post public.content_posts%rowtype;
  normalized_body text := btrim(coalesce(requested_body, ''));
  created_reply_id bigint;
begin
  select * into strict target_post from public.content_posts post where post.id = target_post_id;
  perform private.assert_content_actor(actor_id, target_post.space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 30, interval '10 minutes'
  );
  if existing_result is not null then
    return (existing_result->>'reply_id')::bigint;
  end if;
  if target_post.status <> 'published' or char_length(normalized_body) not between 1 and 5000 then
    raise exception using errcode = '22023', message = 'invalid_content_reply';
  end if;
  if target_parent_reply_id is not null and not exists (
    select 1 from public.content_replies parent
    where parent.id = target_parent_reply_id
      and parent.post_id = target_post_id
      and parent.parent_reply_id is null
      and parent.status = 'published'
  ) then
    raise exception using errcode = '22023', message = 'invalid_content_reply_parent';
  end if;

  insert into public.content_replies (post_id, author_id, parent_reply_id, body)
  values (target_post_id, actor_id, target_parent_reply_id, normalized_body)
  returning id into created_reply_id;
  perform private.replace_content_mentions(
    actor_id, target_post.space_id, null, created_reply_id, mentioned_user_ids
  );
  insert into public.content_audit_events (space_id, actor_id, post_id, reply_id, event_type)
  values (target_post.space_id, actor_id, target_post_id, created_reply_id, 'reply_created');
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('reply_id', created_reply_id)
  );
  return created_reply_id;
end;
$$;

create or replace function public.edit_content_reply(
  acting_user_id uuid,
  target_reply_id bigint,
  requested_body text,
  mentioned_user_ids uuid[],
  request_key uuid
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'edit_reply';
  existing_result jsonb;
  target_reply public.content_replies%rowtype;
  target_space_id bigint;
  normalized_body text := btrim(coalesce(requested_body, ''));
begin
  select * into strict target_reply
  from public.content_replies reply
  where reply.id = target_reply_id
  for update;
  select post.space_id into strict target_space_id
  from public.content_posts post where post.id = target_reply.post_id;
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 30, interval '10 minutes'
  );
  if existing_result is not null then
    return (existing_result->>'reply_id')::bigint;
  end if;
  if target_reply.author_id <> actor_id or target_reply.status <> 'published'
     or char_length(normalized_body) not between 1 and 5000 then
    raise exception using errcode = '42501', message = 'content_reply_edit_forbidden';
  end if;
  update public.content_replies
  set body = normalized_body, edited_at = statement_timestamp()
  where id = target_reply_id;
  perform private.replace_content_mentions(
    actor_id, target_space_id, null, target_reply_id, mentioned_user_ids
  );
  insert into public.content_audit_events (space_id, actor_id, post_id, reply_id, event_type)
  values (target_space_id, actor_id, target_reply.post_id, target_reply_id, 'reply_edited');
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('reply_id', target_reply_id)
  );
  return target_reply_id;
end;
$$;

create or replace function public.delete_content_reply(
  acting_user_id uuid,
  target_reply_id bigint,
  request_key uuid
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'delete_reply';
  existing_result jsonb;
  target_reply public.content_replies%rowtype;
  target_space_id bigint;
  resulting_status text;
  actor_role text;
  author_role text;
begin
  select * into strict target_reply
  from public.content_replies reply
  where reply.id = target_reply_id
  for update;
  select post.space_id into strict target_space_id
  from public.content_posts post where post.id = target_reply.post_id;
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 20, interval '10 minutes'
  );
  if existing_result is not null then
    return existing_result->>'status';
  end if;
  if target_reply.status <> 'published' then
    raise exception using errcode = '55000', message = 'content_reply_not_published';
  end if;
  if target_reply.author_id = actor_id then
    resulting_status := 'deleted';
  elsif private.is_space_moderator(target_space_id, actor_id) then
    select membership.role into actor_role
    from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = actor_id
      and membership.status = 'active';
    select membership.role into author_role
    from public.space_memberships membership
    where membership.space_id = target_space_id
      and membership.user_id = target_reply.author_id
      and membership.status = 'active';
    if actor_role = 'moderator' and author_role in ('owner', 'moderator') then
      raise exception using errcode = '42501', message = 'protected_content_author_role';
    end if;
    resulting_status := 'removed';
  else
    raise exception using errcode = '42501', message = 'content_reply_delete_forbidden';
  end if;
  update public.content_replies
  set
    status = resulting_status,
    deleted_at = statement_timestamp(),
    removed_by = case when resulting_status = 'removed' then actor_id else null end
  where id = target_reply_id;
  insert into public.content_audit_events (space_id, actor_id, post_id, reply_id, event_type)
  values (
    target_space_id, actor_id, target_reply.post_id, target_reply_id,
    case when resulting_status = 'removed' then 'reply_removed' else 'reply_deleted' end
  );
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('status', resulting_status)
  );
  return resulting_status;
end;
$$;

create or replace function public.set_content_reaction(
  acting_user_id uuid,
  target_type text,
  target_id bigint,
  requested_reaction text,
  request_key uuid
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'set_reaction';
  existing_result jsonb;
  target_space_id bigint;
  target_post_id bigint;
begin
  if target_type = 'post' then
    select post.space_id, post.id into strict target_space_id, target_post_id
    from public.content_posts post where post.id = target_id and post.status = 'published';
  elsif target_type = 'reply' then
    select post.space_id, post.id into strict target_space_id, target_post_id
    from public.content_replies reply
    join public.content_posts post on post.id = reply.post_id
    where reply.id = target_id and reply.status = 'published' and post.status = 'published';
  else
    raise exception using errcode = '22023', message = 'invalid_content_reaction_target';
  end if;
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 120, interval '10 minutes'
  );
  if existing_result is not null then
    return existing_result->>'reaction';
  end if;
  if requested_reaction is not null
     and requested_reaction not in ('apresiasi', 'membantu', 'menarik') then
    raise exception using errcode = '22023', message = 'invalid_content_reaction';
  end if;

  if target_type = 'post' then
    delete from public.content_reactions reaction
    where reaction.post_id = target_id and reaction.actor_id = acting_user_id;
    if requested_reaction is not null then
      insert into public.content_reactions (actor_id, post_id, reaction)
      values (actor_id, target_id, requested_reaction);
    end if;
  else
    delete from public.content_reactions reaction
    where reaction.reply_id = target_id and reaction.actor_id = acting_user_id;
    if requested_reaction is not null then
      insert into public.content_reactions (actor_id, reply_id, reaction)
      values (actor_id, target_id, requested_reaction);
    end if;
  end if;
  insert into public.content_audit_events (space_id, actor_id, post_id, reply_id, event_type, details)
  values (
    target_space_id, actor_id, target_post_id,
    case when target_type = 'reply' then target_id else null end,
    case when requested_reaction is null then 'reaction_removed' else 'reaction_set' end,
    jsonb_build_object('reaction', requested_reaction)
  );
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name,
    jsonb_build_object('reaction', coalesce(requested_reaction, 'removed'))
  );
  return coalesce(requested_reaction, 'removed');
end;
$$;

create or replace function public.set_content_saved(
  acting_user_id uuid,
  target_post_id bigint,
  should_save boolean,
  request_key uuid
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'set_saved';
  existing_result jsonb;
  target_space_id bigint;
begin
  select post.space_id into strict target_space_id
  from public.content_posts post
  where post.id = target_post_id and post.status = 'published';
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 120, interval '10 minutes'
  );
  if existing_result is not null then
    return (existing_result->>'saved')::boolean;
  end if;
  if should_save then
    insert into public.content_saves (user_id, post_id)
    values (actor_id, target_post_id)
    on conflict do nothing;
  else
    delete from public.content_saves saved
    where saved.user_id = actor_id and saved.post_id = target_post_id;
  end if;
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name, jsonb_build_object('saved', should_save)
  );
  return should_save;
end;
$$;

create or replace function public.vote_content_poll(
  acting_user_id uuid,
  target_post_id bigint,
  selected_option_ids bigint[],
  request_key uuid
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'vote_poll';
  existing_result jsonb;
  target_space_id bigint;
  target_poll public.content_polls%rowtype;
  selected_count integer := cardinality(coalesce(selected_option_ids, array[]::bigint[]));
  inserted_count integer;
begin
  select * into strict target_poll
  from public.content_polls poll where poll.post_id = target_post_id;
  select post.space_id into strict target_space_id
  from public.content_posts post
  where post.id = target_post_id and post.status = 'published';
  perform private.assert_content_actor(actor_id, target_space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 40, interval '10 minutes'
  );
  if existing_result is not null then
    return (existing_result->>'selected_count')::integer;
  end if;
  if target_poll.ends_at is not null and target_poll.ends_at <= statement_timestamp() then
    raise exception using errcode = '55000', message = 'content_poll_closed';
  end if;
  if selected_count < 1 or selected_count > 10
     or (not target_poll.allows_multiple and selected_count <> 1)
     or selected_count <> (select count(distinct option_id)::integer from unnest(selected_option_ids) option_id) then
    raise exception using errcode = '22023', message = 'invalid_content_poll_vote';
  end if;
  if selected_count <> (
    select count(*)::integer
    from public.content_poll_options option
    where option.post_id = target_post_id
      and option.id = any(selected_option_ids)
  ) then
    raise exception using errcode = '22023', message = 'content_poll_option_mismatch';
  end if;

  delete from public.content_poll_votes vote
  where vote.post_id = target_post_id and vote.voter_id = actor_id;
  insert into public.content_poll_votes (post_id, option_id, voter_id)
  select target_post_id, option_id, actor_id from unnest(selected_option_ids) option_id;
  get diagnostics inserted_count = row_count;
  update public.content_poll_options option
  set vote_count = (
    select count(*)::integer from public.content_poll_votes vote where vote.option_id = option.id
  )
  where option.post_id = target_post_id;
  insert into public.content_audit_events (space_id, actor_id, post_id, event_type, details)
  values (
    target_space_id, actor_id, target_post_id, 'poll_voted',
    jsonb_build_object('selected_count', inserted_count)
  );
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name,
    jsonb_build_object('selected_count', inserted_count)
  );
  return inserted_count;
end;
$$;

create or replace function public.accept_content_answer(
  acting_user_id uuid,
  target_post_id bigint,
  target_reply_id bigint,
  request_key uuid
)
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  actor_id uuid := acting_user_id;
  operation_name constant text := 'accept_answer';
  existing_result jsonb;
  target_post public.content_posts%rowtype;
begin
  select * into strict target_post
  from public.content_posts post
  where post.id = target_post_id
  for update;
  perform private.assert_content_actor(actor_id, target_post.space_id);
  existing_result := private.begin_content_mutation(
    actor_id, request_key, operation_name, 20, interval '10 minutes'
  );
  if existing_result is not null then
    return nullif(existing_result->>'reply_id', '')::bigint;
  end if;
  if target_post.kind <> 'question' or target_post.status <> 'published'
     or target_post.author_id <> actor_id then
    raise exception using errcode = '42501', message = 'content_question_author_required';
  end if;
  if target_reply_id is not null and not exists (
    select 1 from public.content_replies reply
    where reply.id = target_reply_id
      and reply.post_id = target_post_id
      and reply.status = 'published'
  ) then
    raise exception using errcode = '22023', message = 'invalid_content_answer';
  end if;
  update public.content_questions
  set
    accepted_reply_id = target_reply_id,
    accepted_by = case when target_reply_id is null then null else actor_id end,
    accepted_at = case when target_reply_id is null then null else statement_timestamp() end
  where post_id = target_post_id;
  insert into public.content_audit_events (space_id, actor_id, post_id, reply_id, event_type)
  values (
    target_post.space_id, actor_id, target_post_id, target_reply_id,
    case when target_reply_id is null then 'answer_unaccepted' else 'answer_accepted' end
  );
  perform private.complete_content_mutation(
    actor_id, request_key, operation_name,
    jsonb_build_object('reply_id', coalesce(target_reply_id::text, ''))
  );
  return target_reply_id;
end;
$$;

revoke execute on function public.register_content_media(uuid, bigint, uuid, text, text, bigint, uuid)
  from public, anon, authenticated;
revoke execute on function public.create_content_post(uuid, bigint, text, text, text, text, text[], boolean, timestamptz, uuid[], uuid[], uuid)
  from public, anon, authenticated;
revoke execute on function public.edit_content_post(uuid, bigint, text, text, text, uuid[], uuid)
  from public, anon, authenticated;
revoke execute on function public.delete_content_post(uuid, bigint, uuid)
  from public, anon, authenticated;
revoke execute on function public.create_content_reply(uuid, bigint, bigint, text, uuid[], uuid)
  from public, anon, authenticated;
revoke execute on function public.edit_content_reply(uuid, bigint, text, uuid[], uuid)
  from public, anon, authenticated;
revoke execute on function public.delete_content_reply(uuid, bigint, uuid)
  from public, anon, authenticated;
revoke execute on function public.set_content_reaction(uuid, text, bigint, text, uuid)
  from public, anon, authenticated;
revoke execute on function public.set_content_saved(uuid, bigint, boolean, uuid)
  from public, anon, authenticated;
revoke execute on function public.vote_content_poll(uuid, bigint, bigint[], uuid)
  from public, anon, authenticated;
revoke execute on function public.accept_content_answer(uuid, bigint, bigint, uuid)
  from public, anon, authenticated;

grant execute on function public.register_content_media(uuid, bigint, uuid, text, text, bigint, uuid)
  to service_role;
grant execute on function public.create_content_post(uuid, bigint, text, text, text, text, text[], boolean, timestamptz, uuid[], uuid[], uuid)
  to service_role;
grant execute on function public.edit_content_post(uuid, bigint, text, text, text, uuid[], uuid)
  to service_role;
grant execute on function public.delete_content_post(uuid, bigint, uuid) to service_role;
grant execute on function public.create_content_reply(uuid, bigint, bigint, text, uuid[], uuid)
  to service_role;
grant execute on function public.edit_content_reply(uuid, bigint, text, uuid[], uuid)
  to service_role;
grant execute on function public.delete_content_reply(uuid, bigint, uuid) to service_role;
grant execute on function public.set_content_reaction(uuid, text, bigint, text, uuid)
  to service_role;
grant execute on function public.set_content_saved(uuid, bigint, boolean, uuid)
  to service_role;
grant execute on function public.vote_content_poll(uuid, bigint, bigint[], uuid)
  to service_role;
grant execute on function public.accept_content_answer(uuid, bigint, bigint, uuid)
  to service_role;
