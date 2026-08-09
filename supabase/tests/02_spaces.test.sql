begin;
drop extension if exists pgtap;
create extension pgtap with schema public;
set local search_path = public;

select no_plan();

select has_table('public', 'spaces', 'spaces table exists');
select has_table('public', 'space_memberships', 'space memberships table exists');
select has_table('public', 'space_rules', 'space rules table exists');
select has_table('public', 'space_join_requests', 'space join requests table exists');
select has_table('public', 'space_invitations', 'space invitations table exists');
select has_table('public', 'space_bans', 'space bans table exists');
select has_table('public', 'space_reputation_entries', 'contextual reputation ledger exists');
select has_table('public', 'space_reputation_balances', 'contextual reputation balances exist');
select has_table('public', 'space_audit_events', 'immutable space audit log exists');

select is(
  (
    select count(*)::integer
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'spaces', 'space_memberships', 'space_rules', 'space_join_requests',
        'space_invitations', 'space_bans', 'space_reputation_entries',
        'space_reputation_balances', 'space_audit_events'
      )
      and relation.relrowsecurity
      and relation.relforcerowsecurity
  ),
  9,
  'every Phase 2 exposed table has forced RLS'
);

select is(has_table_privilege('anon', 'public.spaces', 'SELECT'), false, 'anon cannot browse spaces');
select is(
  has_table_privilege('authenticated', 'public.spaces', 'SELECT'),
  true,
  'authenticated users can browse RLS-filtered spaces'
);
select is(
  has_table_privilege('authenticated', 'public.spaces', 'INSERT'),
  false,
  'authenticated clients cannot bypass audited mutation RPCs'
);
select is(
  has_function_privilege(
    'authenticated',
    'public.create_space(uuid,text,text,text,text,text)',
    'EXECUTE'
  ),
  false,
  'browser role cannot execute server-only space creation'
);
select is(
  has_function_privilege(
    'service_role',
    'public.create_space(uuid,text,text,text,text,text)',
    'EXECUTE'
  ),
  true,
  'trusted server role can execute audited space creation'
);
select is(
  (
    select count(*)::integer
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'create_space', 'join_space', 'leave_space', 'review_space_join_request',
        'invite_space_member', 'set_space_member_role', 'transfer_space_ownership',
        'ban_space_member', 'unban_space_member', 'add_space_reputation',
        'upsert_space_rule', 'remove_space_rule'
      )
      and procedure.prosecdef
  ),
  0,
  'every exposed Phase 2 RPC is security invoker'
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
  'Phase 2 policies avoid deprecated roles and user-editable metadata'
);

create temporary table phase_2_test_state (
  state_key text primary key,
  state_value text not null
) on commit drop;
grant select, insert, update on table phase_2_test_state to authenticated, service_role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-111111111111","role":"authenticated","app_metadata":{}}',
  true
);
select is(
  (public.complete_identity_onboarding('space_owner', 'Space Owner', '18plus-v1', 'closed-beta-v1')).handle,
  'space_owner',
  'owner fixture completes identity onboarding'
);

select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-222222222222","role":"authenticated","app_metadata":{}}',
  true
);
select is(
  (public.complete_identity_onboarding('space_member', 'Space Member', '18plus-v1', 'closed-beta-v1')).handle,
  'space_member',
  'member fixture completes identity onboarding'
);

select set_config('request.jwt.claim.sub', '33333333-3333-4333-8333-333333333333', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"33333333-3333-4333-8333-333333333333","role":"authenticated","app_metadata":{}}',
  true
);
select is(
  (public.complete_identity_onboarding('space_moderator', 'Space Moderator', '18plus-v1', 'closed-beta-v1')).handle,
  'space_moderator',
  'moderator fixture completes identity onboarding'
);

select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated","app_metadata":{}}',
  true
);
select is(
  (public.complete_identity_onboarding('space_outsider', 'Space Outsider', '18plus-v1', 'closed-beta-v1')).handle,
  'space_outsider',
  'outsider fixture completes identity onboarding'
);
reset role;

set local role service_role;

insert into phase_2_test_state (state_key, state_value)
select
  'open_space_id',
  (
    public.create_space(
      '11111111-1111-4111-8111-111111111111',
      'komunitas-terbuka',
      'Komunitas Terbuka',
      'Ruang uji kebijakan open.',
      'open',
      'public'
    )
  ).id::text;

select is(
  (
    select slug from public.spaces
    where id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  'komunitas-terbuka',
  'trusted mutation creates a normalized space'
);
select is(
  (
    select role
    from public.space_memberships
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and user_id = '11111111-1111-4111-8111-111111111111'
  ),
  'owner',
  'space creation atomically installs its owner membership'
);
select is(
  (
    select count(*)::integer from public.space_audit_events
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and event_type = 'space_created'
  ),
  1,
  'space creation is auditable'
);

select is(
  public.join_space(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  'joined',
  'open space admits an onboarded member'
);
select is(
  public.join_space(
    '22222222-2222-4222-8222-222222222222',
    (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  'already_member',
  'joining an active membership is idempotent'
);
select is(
  (
    public.set_space_member_role(
      '11111111-1111-4111-8111-111111111111',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      '22222222-2222-4222-8222-222222222222',
      'moderator'
    )
  ).role,
  'moderator',
  'owner can delegate the moderator role'
);

select is(
  public.join_space(
    '44444444-4444-4444-8444-444444444444',
    (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  'joined',
  'outsider can initially join an open space'
);
select is(
  (
    public.ban_space_member(
      '11111111-1111-4111-8111-111111111111',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      '44444444-4444-4444-8444-444444444444',
      'Pelanggaran aturan uji',
      null
    )
  ).reason,
  'Pelanggaran aturan uji',
  'owner can issue a reasoned space ban'
);
select is(
  (
    select status from public.space_memberships
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and user_id = '44444444-4444-4444-8444-444444444444'
  ),
  'left',
  'ban immediately removes active membership'
);

select throws_ok(
  format(
    'select public.join_space(%L::uuid, %s::bigint)',
    '44444444-4444-4444-8444-444444444444',
    (select state_value from phase_2_test_state where state_key = 'open_space_id')
  ),
  '42501',
  'space_membership_banned',
  'active ban takes precedence over open join policy'
);

select is(
  (
    public.transfer_space_ownership(
      '11111111-1111-4111-8111-111111111111',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      '22222222-2222-4222-8222-222222222222'
    )
  ).owner_id,
  '22222222-2222-4222-8222-222222222222'::uuid,
  'ownership transfers only through the audited transaction'
);
select is(
  (
    select count(*)::integer from public.space_memberships
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and role = 'owner' and status = 'active'
  ),
  1,
  'ownership transfer preserves exactly one active owner'
);
select is(
  (
    select role from public.space_memberships
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and user_id = '11111111-1111-4111-8111-111111111111'
  ),
  'moderator',
  'previous owner becomes a moderator after transfer'
);
select is(
  (
    select count(*)::integer from public.space_audit_events
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and event_type = 'ownership_transferred'
  ),
  1,
  'ownership transfer is auditable'
);

insert into phase_2_test_state (state_key, state_value)
select
  'reputation_entry_id',
  (
    public.add_space_reputation(
      '22222222-2222-4222-8222-222222222222',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      '11111111-1111-4111-8111-111111111111',
      5::smallint,
      'Kontribusi komunitas uji',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
    )
  ).id::text;

select is(
  (
    public.add_space_reputation(
      '22222222-2222-4222-8222-222222222222',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      '11111111-1111-4111-8111-111111111111',
      5::smallint,
      'Kontribusi komunitas uji',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid
    )
  ).id,
  (select state_value::bigint from phase_2_test_state where state_key = 'reputation_entry_id'),
  'reputation mutation is idempotent by caller request key'
);
select is(
  (
    select score from public.space_reputation_balances
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and user_id = '11111111-1111-4111-8111-111111111111'
  ),
  5::bigint,
  'contextual reputation balance derives from the append-only ledger'
);
select is(
  (
    select count(*)::integer from public.space_reputation_entries
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and idempotency_key = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  ),
  1,
  'idempotent retry never duplicates the reputation ledger entry'
);

insert into phase_2_test_state (state_key, state_value)
select
  'rule_id',
  (
    public.upsert_space_rule(
      '22222222-2222-4222-8222-222222222222',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      null::bigint,
      1::smallint,
      'Hormati konteks',
      'Bahas ide tanpa menyerang orang.',
      true
    )
  ).id::text;
select is(
  (
    select title from public.space_rules
    where id = (select state_value::bigint from phase_2_test_state where state_key = 'rule_id')
  ),
  'Hormati konteks',
  'moderator can maintain ordered space rules'
);

insert into phase_2_test_state (state_key, state_value)
select
  'invite_space_id',
  (
    public.create_space(
      '33333333-3333-4333-8333-333333333333',
      'komunitas-undangan',
      'Komunitas Undangan',
      'Ruang uji kebijakan invite.',
      'invite',
      'private'
    )
  ).id::text;
select is(
  (
    public.invite_space_member(
      '33333333-3333-4333-8333-333333333333',
      (select state_value::bigint from phase_2_test_state where state_key = 'invite_space_id'),
      '44444444-4444-4444-8444-444444444444',
      statement_timestamp() + interval '1 day'
    )
  ).status,
  'pending',
  'moderator can issue a scoped invitation'
);
select is(
  public.join_space(
    '44444444-4444-4444-8444-444444444444',
    (select state_value::bigint from phase_2_test_state where state_key = 'invite_space_id')
  ),
  'joined',
  'valid invitation admits its intended user'
);
select is(
  (
    select status from public.space_invitations
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'invite_space_id')
      and user_id = '44444444-4444-4444-8444-444444444444'
  ),
  'accepted',
  'accepted invitation retains its audit state'
);

insert into phase_2_test_state (state_key, state_value)
select
  'request_space_id',
  (
    public.create_space(
      '33333333-3333-4333-8333-333333333333',
      'komunitas-permintaan',
      'Komunitas Permintaan',
      'Ruang uji kebijakan request.',
      'request',
      'public'
    )
  ).id::text;
select is(
  public.join_space(
    '44444444-4444-4444-8444-444444444444',
    (select state_value::bigint from phase_2_test_state where state_key = 'request_space_id')
  ),
  'requested',
  'request-gated space queues a join request'
);
insert into phase_2_test_state (state_key, state_value)
select 'join_request_id', id::text
from public.space_join_requests
where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'request_space_id')
  and user_id = '44444444-4444-4444-8444-444444444444'
  and status = 'pending';
select is(
  (
    public.review_space_join_request(
      '33333333-3333-4333-8333-333333333333',
      (select state_value::bigint from phase_2_test_state where state_key = 'join_request_id'),
      'approved'
    )
  ).status,
  'approved',
  'space moderator can approve a pending join request'
);
select is(
  (
    select status from public.space_memberships
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'request_space_id')
      and user_id = '44444444-4444-4444-8444-444444444444'
  ),
  'active',
  'approved request atomically activates membership'
);

select is(
  (
    public.invite_space_member(
      '33333333-3333-4333-8333-333333333333',
      (select state_value::bigint from phase_2_test_state where state_key = 'request_space_id'),
      '11111111-1111-4111-8111-111111111111',
      statement_timestamp() + interval '1 day'
    )
  ).status,
  'pending',
  'moderator can invite directly into a request-gated space'
);
select is(
  public.join_space(
    '11111111-1111-4111-8111-111111111111',
    (select state_value::bigint from phase_2_test_state where state_key = 'request_space_id')
  ),
  'joined',
  'valid invitation takes precedence over request gating'
);
select is(
  (
    select status from public.space_invitations
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'request_space_id')
      and user_id = '11111111-1111-4111-8111-111111111111'
  ),
  'accepted',
  'request-space invitation retains its accepted audit state'
);

select is(
  (
    public.unban_space_member(
      '22222222-2222-4222-8222-222222222222',
      (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
      '44444444-4444-4444-8444-444444444444'
    )
  ).revoked_by,
  '22222222-2222-4222-8222-222222222222'::uuid,
  'current owner can revoke an active ban'
);
select is(
  public.join_space(
    '44444444-4444-4444-8444-444444444444',
    (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  'joined',
  'unbanned user can join again under the space policy'
);
select is(
  (
    select count(*)::integer from public.space_audit_events
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and event_type in ('member_banned', 'member_unbanned')
  ),
  2,
  'ban lifecycle remains fully auditable'
);

select public.remove_space_rule(
  '22222222-2222-4222-8222-222222222222',
  (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id'),
  (select state_value::bigint from phase_2_test_state where state_key = 'rule_id')
);
select is(
  (
    select count(*)::integer from public.space_rules
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  0,
  'rule removal deletes only the targeted rule'
);

reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '44444444-4444-4444-8444-444444444444', true);
select set_config(
  'request.jwt.claims',
  '{"sub":"44444444-4444-4444-8444-444444444444","role":"authenticated","app_metadata":{}}',
  true
);
select is(
  (
    select count(*)::integer from public.spaces
    where slug in ('komunitas-terbuka', 'komunitas-permintaan')
  ),
  2,
  'authenticated member can discover public spaces through RLS'
);
select is(
  (
    select count(*)::integer from public.space_audit_events
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and event_type = 'space_created'
  ),
  0,
  'ordinary member cannot read moderator-only unrelated audit events'
);
select is(
  (
    select count(*)::integer from public.space_bans
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
      and user_id = '44444444-4444-4444-8444-444444444444'
  ),
  1,
  'affected user can inspect its own moderation record'
);
select is(
  (
    select count(*)::integer from public.space_reputation_balances
    where space_id = (select state_value::bigint from phase_2_test_state where state_key = 'open_space_id')
  ),
  1,
  'active member can read contextual balances without raw ledger access'
);

reset role;
select * from finish();
rollback;
