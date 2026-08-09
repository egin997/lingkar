-- Stable fingerprint for all repository-owned schema objects through Phase 2.
with repository_tables(table_name) as (
  values
    ('identity_accounts'), ('profiles'), ('spaces'), ('space_memberships'),
    ('space_rules'), ('space_join_requests'), ('space_invitations'), ('space_bans'),
    ('space_reputation_entries'), ('space_reputation_balances'), ('space_audit_events')
),
object_definitions as (
  select format(
    'column:%I.%I.%I:%s:%s:%s',
    namespace.nspname,
    relation.relname,
    attribute.attname,
    pg_catalog.format_type(attribute.atttypid, attribute.atttypmod),
    attribute.attnotnull,
    coalesce(pg_get_expr(default_value.adbin, default_value.adrelid), '')
  ) as definition
  from pg_catalog.pg_attribute attribute
  join pg_catalog.pg_class relation on relation.oid = attribute.attrelid
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  join repository_tables owned on owned.table_name = relation.relname
  left join pg_catalog.pg_attrdef default_value
    on default_value.adrelid = attribute.attrelid and default_value.adnum = attribute.attnum
  where namespace.nspname = 'public' and attribute.attnum > 0 and not attribute.attisdropped

  union all

  select format(
    'constraint:%I.%I:%s', namespace.nspname, relation.relname, pg_get_constraintdef(constraint_row.oid, true)
  )
  from pg_catalog.pg_constraint constraint_row
  join pg_catalog.pg_class relation on relation.oid = constraint_row.conrelid
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  join repository_tables owned on owned.table_name = relation.relname
  where namespace.nspname = 'public'

  union all

  select format('index:%I.%I:%s', schemaname, tablename, indexdef)
  from pg_catalog.pg_indexes
  where schemaname = 'public' and tablename in (select table_name from repository_tables)

  union all

  select format(
    'policy:%I.%I:%s:%s:%s:%s:%s',
    schemaname, tablename, policyname, cmd, roles, coalesce(qual, ''), coalesce(with_check, '')
  )
  from pg_catalog.pg_policies
  where schemaname = 'public' and tablename in (select table_name from repository_tables)

  union all

  select format('function:%I.%I:%s', namespace.nspname, procedure.proname, pg_get_functiondef(procedure.oid))
  from pg_catalog.pg_proc procedure
  join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
  where (namespace.nspname = 'private' and procedure.proname in (
      'set_updated_at', 'bootstrap_identity_account', 'is_active_space_member',
      'is_space_moderator', 'apply_space_reputation_entry'
    ))
    or (namespace.nspname = 'public' and procedure.proname in (
      'complete_identity_onboarding', 'create_space', 'join_space', 'leave_space',
      'review_space_join_request', 'invite_space_member', 'set_space_member_role',
      'transfer_space_ownership', 'ban_space_member', 'unban_space_member',
      'add_space_reputation', 'upsert_space_rule', 'remove_space_rule'
    ))

  union all

  select format('trigger:%s', pg_get_triggerdef(trigger_row.oid, true))
  from pg_catalog.pg_trigger trigger_row
  join pg_catalog.pg_class relation on relation.oid = trigger_row.tgrelid
  join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
  where not trigger_row.tgisinternal
    and (
      (namespace.nspname = 'public' and relation.relname in (select table_name from repository_tables))
      or (namespace.nspname = 'auth' and trigger_row.tgname = 'auth_user_bootstrap_identity_account')
    )
)
select
  md5(string_agg(definition, E'\n' order by definition)) as phase_2_schema_fingerprint,
  count(*)::integer as repository_object_count
from object_definitions;
