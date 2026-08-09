-- Phase 0 owns cross-cutting database primitives only. Product tables belong to later phases.
create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  return new;
end;
$$;

revoke execute on function private.set_updated_at() from public, anon, authenticated;
grant execute on function private.set_updated_at() to service_role;
