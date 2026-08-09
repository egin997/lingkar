-- Docker-free verification of the same four pgTAP assertions used by
-- supabase/tests/00_foundation.test.sql. This proves the remote schema and pgTAP
-- extension work, but it does not replace the required `supabase test db --linked`
-- runner gate.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(4);

create temporary table phase_0_tap_results (
  assertion_number integer primary key,
  result text not null
) on commit drop;

insert into phase_0_tap_results (assertion_number, result)
with tap_results as (
  select 1 as assertion_number,
    has_schema('private', 'private schema exists') as result

  union all

  select 2,
    has_function(
      'private',
      'set_updated_at',
      array[]::text[],
      'updated_at trigger exists'
    )

  union all

  select 3,
    is(
      has_schema_privilege('anon', 'private', 'USAGE'),
      false,
      'anon cannot use private schema'
    )

  union all

  select 4,
    is(
      has_function_privilege('anon', 'private.set_updated_at()', 'EXECUTE'),
      false,
      'anon cannot invoke private trigger function'
    )
)
select assertion_number, result from tap_results;

do $$
begin
  if not (
    select count(*) = 4 and bool_and(result like 'ok %')
    from phase_0_tap_results
  ) then
    raise exception 'one or more Phase 0 pgTAP assertions failed';
  end if;
end;
$$;

select * from finish();

select
  jsonb_agg(result order by assertion_number) as assertions,
  bool_and(result like 'ok %') as all_passed,
  'PASS' as result
from phase_0_tap_results;

rollback;
