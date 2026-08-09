# Phase 0 — Foundation audit

Audit date: **2026-08-09 (Asia/Jakarta)**

Overall status: **BLOCKED — one required runner gate failed**

Phase 1 status: **LOCKED / NOT STARTED**

Phase 0 is not `VERIFIED COMPLETE`. No baseline commit or tag may be created until the exact
`supabase test db --linked` gate exits successfully.

## Target and safety record

| Field | Evidence |
| --- | --- |
| Supabase CLI | `2.113.0` |
| Command syntax | `--help` checked for `link`, `db push`, `db reset`, `test db`, `db lint`, and `db advisors` |
| Project ref | `nwiyakbolnumldkrvsim` (non-secret identifier) |
| Project name | `egin997's Project` |
| Environment | owner-confirmed disposable audit project |
| Region / Postgres | `ap-southeast-1` / remote server `17.6` |
| Safety acknowledgement | exact ref + `disposable` + `RESET_DISPOSABLE_DATABASE_ONLY` |
| Link verification | `supabase projects list` reported this ref as linked and `ACTIVE_HEALTHY` |
| Secrets | no access token, database password, service-role key, or API key recorded in this artifact |

The destructive reset authorization applies only to the project ref above. Every remote npm script
runs `scripts/assert-disposable-supabase.mjs` first and fails closed if the linked ref or the three
safety variables do not match.

## Initial remote snapshot

Before the first reset, the disposable project had no migration history and contained one unmanaged
empty table, `public.obrolan_jarvis`, with RLS enabled. Advisors also reported an RLS-without-policy
info item and two security warnings for a client-executable `SECURITY DEFINER` helper. The guarded
reset removed all of those unmanaged objects. Post-reset advisors report no issues.

## Acceptance evidence

| Criterion | Command / evidence | Result |
| --- | --- | --- |
| Reproducible install | `npm ci` — 755 packages installed, 756 audited, 0 vulnerabilities | **PASS** |
| Lint | `npm run lint` via final `npm run check`; zero warnings allowed | **PASS** |
| Strict typecheck | `tsc --noEmit` | **PASS** |
| Unit tests | Vitest: 4 files, 17 tests | **PASS** |
| Coverage | statements 22/22, branches 15/15, functions 5/5, lines 22/22 | **PASS** |
| Production build | Next.js `16.3.0`; `/`, `/_not-found`, `/api/health` built | **PASS** |
| OpenNext Cloudflare build | OpenNext `1.20.2`; `.open-next/worker.js` generated | **PASS** |
| Workerd smoke | `npm run cf:smoke`; `/` 200, health 200 + `no-store`, CSP present, frame policy `DENY` | **PASS** |
| Wrangler dry-run | `npm run cf:dry-run`; Wrangler `4.120.0`; 37 assets; 4738.50 KiB raw / 994.44 KiB gzip | **PASS** |
| CLI login | `supabase projects list --output json` | **PASS** |
| Safe linked target | link metadata and fail-closed target guard matched the authorized disposable ref | **PASS** |
| Initial linked dry-run | one pending migration, no roles or seed changes | **PASS** |
| Final linked dry-run | `upToDate: true`; no pending migrations, seeds, or roles | **PASS** |
| Clean migration replay | guarded `supabase db reset --linked --yes`; migration and empty seed applied | **PASS** |
| Migration history | local and remote both `20260809001207` | **PASS** |
| pgTAP SQL on linked DB | `npm run db:remote:test:sql`; four named assertions, `all_passed: true` | **PASS (supplemental)** |
| Required pgTAP CLI runner | `npm run db:remote:test` → `supabase test db --linked` | **FAIL — Docker runner unavailable** |
| Database lint | `supabase db lint --linked --level warning --fail-on error`; no schema errors | **PASS** |
| Database/security advisors | `supabase db advisors --linked --type all --level info --fail-on error`; no issues | **PASS** |
| Live RLS/security audit | `npm run db:remote:security`; all server-side assertions completed | **PASS** |
| Deterministic replay | two clean resets produced fingerprint `746db563a68746d715a910ec5c7b9f06` with 2 repository objects | **PASS** |
| Dashboard independence | both replays used only repository migration/seed files; no manual dashboard edits | **PASS** |
| Git baseline / tag | forbidden until every acceptance row passes | **LOCKED** |

## pgTAP runner blocker

The final required command failed before running any SQL:

```text
LegacyDockerRunError: failed to run docker. Docker Desktop is a prerequisite
```

`--linked` selects the remote database, but Supabase CLI `2.113.0` still launches `pg_prove` in a
container. The local environment has no Docker, Podman, `pg_prove`, PostgreSQL client, or Perl.

To prove that this is a runner-only blocker, the repository executes the same four pgTAP assertions
directly against the linked database through `supabase db query`. The supplemental runner returns:

```text
ok 1 - private schema exists
ok 2 - updated_at trigger exists
ok 3 - anon cannot use private schema
ok 4 - anon cannot invoke private trigger function
all_passed: true
```

The test creates pgTAP inside its transaction without a version clause and rolls it back. This keeps
test tooling out of the runtime schema and lets the normal database lint inspect only persistent
objects. This evidence does **not** reclassify the required CLI runner as PASS.

## Migration and security audit

- The Phase 0 migration creates no application tables in exposed schemas. Live audit confirmed
  `exposed_table_count = 0`; therefore there is no exposed table missing RLS.
- The live audit is fail-closed for future tables: every table in exposed schemas must have RLS.
- No policy uses deprecated `auth.role()` or authorization based on user-editable `user_metadata`.
- There are no UPDATE or ALL policies in Phase 0. The audit rejects future UPDATE/ALL policies that
  omit either `USING` or `WITH CHECK`.
- The only repository function is `private.set_updated_at()`: `SECURITY INVOKER`, explicit empty
  search path, no execution for `public`, `anon`, or `authenticated`.
- The `private` schema is unavailable to client roles; only `service_role` receives required usage
  and function execution. No service-role secret appears in client code or public environment docs.
- No migration pins an extension version. The pgTAP test also omits a version clause so Supabase
  selects its supported version.
- Advisors returned zero security and performance findings after each final replay.

## Replay evidence

The final migration was replayed twice from an empty disposable database:

1. Guarded reset applied `20260809001207_phase_0_foundation.sql`, then the empty seed file.
2. Fingerprint: `746db563a68746d715a910ec5c7b9f06`; object count: 2.
3. A second guarded reset replayed the same files.
4. Fingerprint remained `746db563a68746d715a910ec5c7b9f06`; object count remained 2.
5. Migration list, supplemental pgTAP, lint, security assertions, and advisors all passed again.

## Unlock condition

Phase 0 remains blocked until `supabase test db --linked` itself exits 0 and reports all tests
successful from an environment with a working container runner. After that single gate passes, rerun
the complete acceptance suite, update this audit to `VERIFIED COMPLETE`, commit the Phase 0 baseline
on `main`, verify a clean working tree, create the roadmap checkpoint/tag if required, and only then
start Phase 1 — Identity.
