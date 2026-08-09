# Phase 0 — Foundation audit

Audit date: **2026-08-09 (Asia/Jakarta)**

Overall status: **VERIFIED COMPLETE ✅**

Phase 1 status: **UNLOCKED / NOT STARTED**

Every mandatory Phase 0 gate passed without lowering its acceptance criterion. The exact
`supabase test db --linked` runner was executed successfully on GitHub Actions with Docker; the
remaining linked-database and application gates were then rerun against the same audited commit.

## Target and safety record

| Field | Evidence |
| --- | --- |
| Supabase CLI | `2.113.0` locally and in the linked pgTAP runner |
| Command syntax | `--help` checked for `link`, `db push`, `db reset`, `test db`, `db lint`, and `db advisors` |
| Project ref | `nwiyakbolnumldkrvsim` (non-secret identifier) |
| Environment | owner-confirmed disposable audit project |
| Region / Postgres | `ap-southeast-1` / remote server `17.6` |
| Safety acknowledgement | exact ref + `disposable` + `RESET_DISPOSABLE_DATABASE_ONLY` |
| Link verification | linked project was reported `ACTIVE_HEALTHY` |
| Secrets | no access token, database password, service-role key, or API key recorded in repository or logs |

Destructive reset authorization applied only to the project ref above. Every remote npm script runs
`scripts/assert-disposable-supabase.mjs` first and fails closed unless the linked ref and all three
safety variables match.

## Acceptance evidence

| Criterion | Command / evidence | Result |
| --- | --- | --- |
| Reproducible install | `npm ci` — 755 packages installed, 756 audited, 0 vulnerabilities | **PASS** |
| Lint | `npm run lint` via final `npm run check`; zero warnings allowed | **PASS** |
| Strict typecheck | `tsc --noEmit` | **PASS** |
| Unit tests | Vitest: 4 files, 17 tests | **PASS** |
| Coverage | statements 22/22, branches 15/15, functions 5/5, lines 22/22 | **PASS** |
| Production build | Next.js `16.3.0`; `/`, `/_not-found`, and `/api/health` built | **PASS** |
| OpenNext Cloudflare build | OpenNext `1.20.2`; `.open-next/worker.js` generated | **PASS** |
| Workerd smoke | `/` 200; health 200 + `no-store`; CSP present; frame policy `DENY` | **PASS** |
| Wrangler dry-run | Wrangler `4.120.0`; 37 assets; 4738.50 KiB raw / 994.46 KiB gzip | **PASS** |
| CLI login and safe link | authenticated CLI plus fail-closed target guard matched the disposable ref | **PASS** |
| Linked dry-run | final `upToDate: true`; no pending migrations, seeds, or roles | **PASS** |
| Clean migration replay | guarded `supabase db reset --linked --yes`; migration and empty seed applied | **PASS** |
| Migration history | local and remote both `20260809001207` | **PASS** |
| Required pgTAP CLI runner | `supabase test db --linked`: Files=1, Tests=4, Result: PASS | **PASS** |
| Supplemental linked pgTAP | four named assertions; `all_passed: true` after final clean replay | **PASS** |
| Database lint | warning-level lint with `--fail-on error`; no schema errors | **PASS** |
| Database/security advisors | security and performance advisors at info level; no issues | **PASS** |
| Live RLS/security audit | all fail-closed server-side assertions completed | **PASS** |
| Deterministic replay | repeated clean resets produced fingerprint `746db563a68746d715a910ec5c7b9f06` and object count 2 | **PASS** |
| Dashboard independence | replay used only repository migration and seed files; no manual dashboard changes | **PASS** |
| Git checkpoint | verified snapshot published to `phase-0-audit-candidate`; local `main` points to the same clean checkpoint | **PASS** |

## Exact pgTAP runner evidence

The required runner passed in GitHub Actions run
[`31291648858`](https://github.com/egin997/lingkar/actions/runs/31291648858), job `93189771187`,
against commit `69697885da6182c3135f8b8c537d5c12777db287`:

```text
supabase/tests/00_foundation.test.sql .. ok
All tests successful.
Files=1, Tests=4, 3 wallclock secs
Result: PASS
```

The test normalizes pgTAP into `public` inside a transaction and rolls the change back. It does not
pin an extension version and leaves no test tooling in the persistent runtime schema.

## Migration, RLS, and security audit

- The Phase 0 migration creates no application tables in exposed schemas. Live audit confirmed
  `exposed_table_count = 0`; therefore no exposed table is missing RLS.
- The audit is fail-closed for future tables: every table in an exposed schema must have RLS.
- No policy uses deprecated `auth.role()` or authorization based on user-editable `user_metadata`.
- There are no UPDATE or ALL policies in Phase 0. The audit rejects future UPDATE/ALL policies that
  omit either `USING` or `WITH CHECK`.
- The only repository function is `private.set_updated_at()`: `SECURITY INVOKER`, explicit empty
  search path, and no execution for `public`, `anon`, or `authenticated`.
- The `private` schema is unavailable to client roles; only `service_role` receives the required
  usage and function execution. No service-role secret appears in client code or public env docs.
- Neither migrations nor pgTAP tests pin extension versions.
- Advisors returned zero security and performance findings after the final replay.

## Replay evidence

1. The guarded reset applied `20260809001207_phase_0_foundation.sql` and the empty seed file.
2. The fingerprint was `746db563a68746d715a910ec5c7b9f06` with object count 2.
3. Repeating the clean replay produced the same fingerprint and object count.
4. Migration list, linked pgTAP, lint, security assertions, advisors, and final dry-run all passed.
5. The final application acceptance suite passed after the database gates.

## Gate decision

**Phase 0 — Foundation: VERIFIED COMPLETE ✅**

**Phase 1 — Identity: UNLOCKED**, but no Phase 1 implementation is included in this checkpoint.
