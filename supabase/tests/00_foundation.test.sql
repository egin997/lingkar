begin;
-- Keep test tooling out of the runtime schema. CREATE EXTENSION is transactional,
-- and Supabase selects the compatible version because no VERSION clause is pinned.
create extension if not exists pgtap with schema extensions;

-- `supabase test db` can provision pgTAP in a runner-selected schema. Resolve
-- that schema through psql instead of assuming the hosted and local layouts match.
select n.nspname as pgtap_schema
from pg_extension e
join pg_namespace n on n.oid = e.extnamespace
where e.extname = 'pgtap'
\gset

set local search_path = public, :"pgtap_schema";

select plan(4);

select has_schema('private', 'private schema exists');
select has_function('private', 'set_updated_at', array[]::text[], 'updated_at trigger exists');

select is(
  has_schema_privilege('anon', 'private', 'USAGE'),
  false,
  'anon cannot use private schema'
);

select is(
  has_function_privilege('anon', 'private.set_updated_at()', 'EXECUTE'),
  false,
  'anon cannot invoke private trigger function'
);

select * from finish();
rollback;
