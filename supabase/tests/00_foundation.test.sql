begin;
-- The CLI may provision pgTAP in a runner-specific schema. Normalize it inside
-- this transaction; rollback restores the prior extension state after the test.
drop extension if exists pgtap;
create extension pgtap with schema public;
set local search_path = public;

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
