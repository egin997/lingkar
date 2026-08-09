begin;
drop extension if exists pgtap;
create extension pgtap with schema public;
set local search_path = public;

select no_plan();

select has_table('public', 'content_posts', 'content posts table exists');
select has_table('public', 'content_post_revisions', 'post edit history exists');
select has_table('public', 'content_media_assets', 'owned media metadata exists');
select has_table('public', 'content_polls', 'poll metadata exists');
select has_table('public', 'content_poll_options', 'poll options exist');
select has_table('public', 'content_poll_votes', 'poll votes exist');
select has_table('public', 'content_replies', 'replies exist');
select has_table('public', 'content_reply_revisions', 'reply edit history exists');
select has_table('public', 'content_questions', 'Q&A acceptance state exists');
select has_table('public', 'content_mentions', 'mentions exist');
select has_table('public', 'content_reactions', 'reactions exist');
select has_table('public', 'content_saves', 'private saves exist');
select has_table('public', 'content_mutation_requests', 'idempotency receipts exist');
select has_table('public', 'content_rate_events', 'rate-limit events exist');
select has_table('public', 'content_audit_events', 'content audit events exist');

select is(
  (
    select count(*)::integer
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'content_posts', 'content_post_revisions', 'content_media_assets',
        'content_polls', 'content_poll_options', 'content_poll_votes',
        'content_replies', 'content_reply_revisions', 'content_questions',
        'content_mentions', 'content_reactions', 'content_saves',
        'content_mutation_requests', 'content_rate_events', 'content_audit_events'
      )
      and relation.relrowsecurity
      and relation.relforcerowsecurity
  ),
  15,
  'every Phase 3 public table has forced RLS'
);

select is(
  has_table_privilege('authenticated', 'public.content_posts', 'SELECT'),
  true,
  'authenticated clients can read RLS-filtered posts'
);
select is(
  has_table_privilege('authenticated', 'public.content_posts', 'INSERT'),
  false,
  'authenticated clients cannot directly create posts'
);
select is(
  has_table_privilege('authenticated', 'public.content_mutation_requests', 'SELECT'),
  false,
  'idempotency receipts are not exposed to browser roles'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.create_content_post(uuid,bigint,text,text,text,text,text[],boolean,timestamp with time zone,uuid[],uuid[],uuid)',
    'EXECUTE'
  ),
  false,
  'browser role cannot execute trusted post creation RPC'
);
select is(
  has_function_privilege(
    'service_role',
    'public.create_content_post(uuid,bigint,text,text,text,text,text[],boolean,timestamp with time zone,uuid[],uuid[],uuid)',
    'EXECUTE'
  ),
  true,
  'trusted server role can execute post creation RPC'
);
select is(
  (
    select count(*)::integer
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'register_content_media', 'create_content_post', 'edit_content_post',
        'delete_content_post', 'create_content_reply', 'edit_content_reply',
        'delete_content_reply', 'set_content_reaction', 'set_content_saved',
        'vote_content_poll', 'accept_content_answer'
      )
      and procedure.prosecdef
  ),
  0,
  'every exposed Phase 3 RPC is security invoker'
);
select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname in ('public', 'storage')
      and (
        coalesce(qual, '') ~* 'auth[.]role[[:space:]]*[(]'
        or coalesce(with_check, '') ~* '(raw_)?user_metadata'
      )
  ),
  0,
  'Phase 3 policies avoid deprecated auth role and user-editable metadata'
);
select is(
  (select public from storage.buckets where id = 'content-media'),
  false,
  'content media bucket is private'
);
select is(
  (select file_size_limit from storage.buckets where id = 'content-media'),
  5242880::bigint,
  'content media bucket enforces a five MiB limit'
);
select is(
  (
    select count(*)::integer from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'content_media_objects_%'
  ),
  4,
  'storage has explicit read, insert, update, and delete ownership policies'
);

create temporary table phase_3_test_state (
  state_key text primary key,
  state_value text not null
) on commit drop;
grant select, insert, update, delete on table phase_3_test_state to authenticated, service_role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{}}', true);
select is(
  (public.complete_identity_onboarding('content_owner', 'Content Owner', '18plus-v1', 'closed-beta-v1')).handle,
  'content_owner',
  'content owner fixture completes onboarding'
);
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{}}', true);
select is(
  (public.complete_identity_onboarding('content_member', 'Content Member', '18plus-v1', 'closed-beta-v1')).handle,
  'content_member',
  'content member fixture completes onboarding'
);
select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{}}', true);
select is(
  (public.complete_identity_onboarding('content_moderator', 'Content Moderator', '18plus-v1', 'closed-beta-v1')).handle,
  'content_moderator',
  'content moderator fixture completes onboarding'
);
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated","app_metadata":{}}', true);
select is(
  (public.complete_identity_onboarding('content_outsider', 'Content Outsider', '18plus-v1', 'closed-beta-v1')).handle,
  'content_outsider',
  'content outsider fixture completes onboarding'
);
reset role;

set local role service_role;
insert into phase_3_test_state (state_key, state_value)
select 'public_space_id', (
  public.create_space(
    '11111111-1111-4111-8111-111111111111',
    'konten-terbuka', 'Konten Terbuka', 'Ruang audit konten', 'open', 'public'
  )
).id::text;
insert into phase_3_test_state (state_key, state_value)
select 'private_space_id', (
  public.create_space(
    '11111111-1111-4111-8111-111111111111',
    'konten-privat', 'Konten Privat', 'Ruang silang tertutup', 'invite', 'private'
  )
).id::text;
select is(
  public.join_space(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id')
  ),
  'joined',
  'member joins the public content space'
);
select is(
  public.join_space(
    '33333333-3333-4333-8333-333333333333',
    (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id')
  ),
  'joined',
  'moderator fixture joins the public content space'
);
select is(
  (
    public.set_space_member_role(
      '11111111-1111-4111-8111-111111111111',
      (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
      '33333333-3333-4333-8333-333333333333',
      'moderator'
    )
  ).role,
  'moderator',
  'owner grants the moderator role'
);

insert into phase_3_test_state (state_key, state_value)
select 'text_post_id', public.create_content_post(
  '11111111-1111-4111-8111-111111111111',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'text', 'space', 'Halo dari post teks', null, array[]::text[], false, null,
  array[]::uuid[], array['22222222-2222-4222-8222-222222222222']::uuid[],
  '30000000-0000-4000-8000-000000000001'
)::text;
select is(
  public.create_content_post(
    '11111111-1111-4111-8111-111111111111',
    (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
    'text', 'space', 'Halo dari post teks', null, array[]::text[], false, null,
    array[]::uuid[], array['22222222-2222-4222-8222-222222222222']::uuid[],
    '30000000-0000-4000-8000-000000000001'
  ),
  (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id'),
  'post creation retry returns the same id'
);
select is(
  (select count(*)::integer from content_posts where body = 'Halo dari post teks'),
  1,
  'idempotent retry does not duplicate a post'
);
select is(
  (select count(*)::integer from content_rate_events where actor_id = '11111111-1111-4111-8111-111111111111' and operation = 'create_post'),
  1,
  'idempotent retry does not consume a second rate event'
);
select is(
  (select count(*)::integer from content_mentions where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id')),
  1,
  'post mention is stored once'
);

insert into phase_3_test_state (state_key, state_value)
select 'members_post_id', public.create_content_post(
  '11111111-1111-4111-8111-111111111111',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'text', 'members', 'Hanya anggota aktif', null, array[]::text[], false, null,
  array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000002'
)::text;
insert into phase_3_test_state (state_key, state_value)
select 'private_post_id', public.create_content_post(
  '11111111-1111-4111-8111-111111111111',
  (select state_value::bigint from phase_3_test_state where state_key = 'private_space_id'),
  'text', 'space', 'Tetap privat karena ruang privat', null, array[]::text[], false, null,
  array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000003'
)::text;

insert into phase_3_test_state (state_key, state_value)
select 'link_post_id', public.create_content_post(
  '22222222-2222-4222-8222-222222222222',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'link', 'space', 'Dokumen rujukan', 'https://example.com/rujukan', array[]::text[], false, null,
  array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000004'
)::text;
select throws_ok(
  $$select public.create_content_post(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
    'link', 'space', 'Link buruk', 'http://example.com', array[]::text[], false, null,
    array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000005'
  )$$,
  '22023', 'invalid_content_link', 'non-HTTPS links are rejected'
);

insert into phase_3_test_state (state_key, state_value)
select 'poll_post_id', public.create_content_post(
  '11111111-1111-4111-8111-111111111111',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'poll', 'space', 'Pilihan terbaik?', null, array['Satu', 'Dua']::text[], false, null,
  array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000006'
)::text;
select is(
  (select count(*)::integer from content_poll_options where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id')),
  2,
  'poll creates its validated options'
);

insert into phase_3_test_state (state_key, state_value)
select 'question_post_id', public.create_content_post(
  '11111111-1111-4111-8111-111111111111',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'question', 'space', 'Bagaimana cara kerjanya?', null, array[]::text[], false, null,
  array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000007'
)::text;
select is(
  (select count(*)::integer from content_questions where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'question_post_id')),
  1,
  'question creates acceptance state'
);

insert into phase_3_test_state (state_key, state_value)
select 'asset_id', (
  public.register_content_media(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
    '50000000-0000-4000-8000-000000000001', 'gambar.webp', 'image/webp', 2048,
    '30000000-0000-4000-8000-000000000008'
  )
).id::text;
select is(
  (select object_path from content_media_assets where id = (select state_value::uuid from phase_3_test_state where state_key = 'asset_id')),
  '22222222-2222-4222-8222-222222222222/50000000-0000-4000-8000-000000000001/gambar.webp',
  'media path is derived from verified ownership'
);
insert into phase_3_test_state (state_key, state_value)
select 'image_post_id', public.create_content_post(
  '22222222-2222-4222-8222-222222222222',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'image', 'space', 'Foto komunitas', null, array[]::text[], false, null,
  array[(select state_value::uuid from phase_3_test_state where state_key = 'asset_id')],
  array[]::uuid[], '30000000-0000-4000-8000-000000000009'
)::text;
select is(
  (select status from content_media_assets where id = (select state_value::uuid from phase_3_test_state where state_key = 'asset_id')),
  'attached',
  'image post atomically attaches owned media metadata'
);

select is(
  public.edit_content_post(
    '11111111-1111-4111-8111-111111111111',
    (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id'),
    'space', 'Halo setelah diedit', null, array[]::uuid[],
    '30000000-0000-4000-8000-000000000010'
  ),
  (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id'),
  'author edits a post'
);
select is(
  (select count(*)::integer from content_post_revisions where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id')),
  1,
  'post edit captures exactly one immutable revision'
);
select is(
  (select body from content_post_revisions where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id')),
  'Halo dari post teks',
  'revision stores the previous post body'
);

insert into phase_3_test_state (state_key, state_value)
select 'answer_reply_id', public.create_content_reply(
  '22222222-2222-4222-8222-222222222222',
  (select state_value::bigint from phase_3_test_state where state_key = 'question_post_id'),
  null, 'Ini jawaban yang relevan', array['11111111-1111-4111-8111-111111111111']::uuid[],
  '30000000-0000-4000-8000-000000000011'
)::text;
select is(
  public.edit_content_reply(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'answer_reply_id'),
    'Ini jawaban yang sudah diperjelas', array[]::uuid[],
    '30000000-0000-4000-8000-000000000012'
  ),
  (select state_value::bigint from phase_3_test_state where state_key = 'answer_reply_id'),
  'reply author edits their reply'
);
select is(
  (select count(*)::integer from content_reply_revisions where reply_id = (select state_value::bigint from phase_3_test_state where state_key = 'answer_reply_id')),
  1,
  'reply edit captures exactly one revision'
);
select is(
  public.accept_content_answer(
    '11111111-1111-4111-8111-111111111111',
    (select state_value::bigint from phase_3_test_state where state_key = 'question_post_id'),
    (select state_value::bigint from phase_3_test_state where state_key = 'answer_reply_id'),
    '30000000-0000-4000-8000-000000000013'
  ),
  (select state_value::bigint from phase_3_test_state where state_key = 'answer_reply_id'),
  'question author accepts an answer'
);
select throws_ok(
  $$select public.accept_content_answer(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'question_post_id'),
    (select state_value::bigint from phase_3_test_state where state_key = 'answer_reply_id'),
    '30000000-0000-4000-8000-000000000014'
  )$$,
  '42501', 'content_question_author_required', 'non-author cannot accept an answer'
);

select is(
  public.vote_content_poll(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id'),
    array[(select min(id) from content_poll_options where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id'))],
    '30000000-0000-4000-8000-000000000015'
  ),
  1,
  'member casts one vote in a single-choice poll'
);
select is(
  (select sum(vote_count)::integer from content_poll_options where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id')),
  1,
  'poll option counters reflect the vote'
);
select throws_ok(
  $$select public.vote_content_poll(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id'),
    array(select id from content_poll_options where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id') order by id),
    '30000000-0000-4000-8000-000000000016'
  )$$,
  '22023', 'invalid_content_poll_vote', 'single-choice poll rejects multiple selections'
);

select is(
  public.set_content_reaction(
    '22222222-2222-4222-8222-222222222222', 'post',
    (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id'),
    'membantu', '30000000-0000-4000-8000-000000000017'
  ),
  'membantu',
  'member reacts to a post'
);
select is(
  public.set_content_saved(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id'),
    true, '30000000-0000-4000-8000-000000000018'
  ),
  true,
  'member saves a post'
);
select is(
  (select count(*)::integer from content_saves where user_id = '22222222-2222-4222-8222-222222222222'),
  1,
  'saved-post relation is unique and persisted'
);

insert into content_rate_events (actor_id, operation, occurred_at)
select '22222222-2222-4222-8222-222222222222', 'create_post', clock_timestamp()
from generate_series(1, 8);
select throws_ok(
  $$select public.create_content_post(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
    'text', 'space', 'Melewati batas', null, array[]::text[], false, null,
    array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000019'
  )$$,
  '54000', 'content_rate_limit_exceeded', 'database rate limiter rejects the eleventh post event'
);
delete from content_rate_events
where actor_id = '22222222-2222-4222-8222-222222222222'
  and operation = 'create_post';
select throws_ok(
  $$select public.set_content_saved(
    '11111111-1111-4111-8111-111111111111',
    (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id'),
    true, '30000000-0000-4000-8000-000000000001'
  )$$,
  '22023', 'idempotency_key_operation_mismatch', 'an idempotency key cannot cross operations'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated","app_metadata":{}}', true);
select is(
  (select count(*)::integer from content_posts where id = (select state_value::bigint from phase_3_test_state where state_key = 'text_post_id')),
  1,
  'outsider can read a space-visible post in a public space'
);
select is(
  (select count(*)::integer from content_posts where id = (select state_value::bigint from phase_3_test_state where state_key = 'members_post_id')),
  0,
  'outsider cannot read a members-only post'
);
select is(
  (select count(*)::integer from content_posts where id = (select state_value::bigint from phase_3_test_state where state_key = 'private_post_id')),
  0,
  'outsider cannot read content across a private space boundary'
);
select throws_ok(
  $$insert into content_posts (space_id, author_id, kind, body)
    values (
      (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
      '44444444-4444-4444-8444-444444444444', 'text', 'bypass'
    )$$,
  '42501',
  'permission denied for table content_posts',
  'authenticated client cannot bypass trusted mutation boundary'
);
select is(
  (select count(*)::integer from content_saves),
  0,
  'another user cannot read private saves'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{}}', true);
select is(
  (select count(*)::integer from content_posts where id = (select state_value::bigint from phase_3_test_state where state_key = 'members_post_id')),
  1,
  'active member can read members-only content'
);
select is(
  (select count(*)::integer from content_saves),
  1,
  'save owner can read their own save'
);
select is(
  (select count(*)::integer from content_poll_votes where post_id = (select state_value::bigint from phase_3_test_state where state_key = 'poll_post_id')),
  1,
  'voter can read their own poll vote'
);

reset role;
set local role service_role;
insert into phase_3_test_state (state_key, state_value)
select 'removal_post_id', public.create_content_post(
  '22222222-2222-4222-8222-222222222222',
  (select state_value::bigint from phase_3_test_state where state_key = 'public_space_id'),
  'text', 'space', 'Konten untuk moderasi', null, array[]::text[], false, null,
  array[]::uuid[], array[]::uuid[], '30000000-0000-4000-8000-000000000020'
)::text;
select is(
  public.delete_content_post(
    '33333333-3333-4333-8333-333333333333',
    (select state_value::bigint from phase_3_test_state where state_key = 'removal_post_id'),
    '30000000-0000-4000-8000-000000000021'
  ),
  'removed',
  'space moderator can remove a member post'
);
select is(
  (select removed_by from content_posts where id = (select state_value::bigint from phase_3_test_state where state_key = 'removal_post_id')),
  '33333333-3333-4333-8333-333333333333'::uuid,
  'moderation removal records the responsible moderator'
);
select ok(
  (select count(*) from content_audit_events) >= 12,
  'content mutations append auditable events'
);

reset role;
select * from finish();
rollback;
