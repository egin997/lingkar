# Phase 1 — Identity audit

Audit date: **2026-08-09 (Asia/Jakarta)**

Overall status: **VERIFIED COMPLETE ✅**

Phase 2 status: **UNLOCKED / NOT STARTED**

Every mandatory Phase 1 gate passed without lowering its acceptance criterion. The final audit
replayed both migrations from an empty disposable database, verified the hosted Auth and RLS
boundaries, ran the complete application and Cloudflare suites, and then passed the exact
`supabase test db --linked` runner on the audited product commit.

## Target and safety record

| Field | Evidence |
| --- | --- |
| Supabase CLI | `2.113.0`; current `--help` syntax checked for linked reset, pgTAP, and lint |
| Project ref | `nwiyakbolnumldkrvsim` (non-secret identifier) |
| Environment | owner-confirmed disposable audit project in `ap-southeast-1` |
| Postgres | hosted `17.6` |
| Reset guard | exact ref + `disposable` + `RESET_DISPOSABLE_DATABASE_ONLY` |
| Secrets | no publishable, secret, legacy service-role, password, or token value logged or committed |

Destructive reset authorization applied only to the project ref above. Every remote npm script
fails closed through `scripts/assert-disposable-supabase.mjs`. Trusted Auth fixtures use two fixed
audit-only UUIDs, are provisioned through the Admin API, and are deleted even when pgTAP fails.

## Acceptance evidence

| Criterion | Command / evidence | Result |
| --- | --- | --- |
| Invite-only Auth | hosted global signup and anonymous signup disabled; email provider enabled | **PASS** |
| Password and confirmation config | email confirmation on; strong password settings pushed and current | **PASS** |
| SSR session refresh | `@supabase/ssr` refresh propagates cookies and private/no-store Auth headers | **PASS** |
| Auth routes | sign-in/out, confirm, recovery, update password, onboarding, and account | **PASS** |
| 18+ privacy | versioned `18plus-v1`; no DOB, email, or password columns in product identity tables | **PASS** |
| Atomic/idempotent onboarding | normalized unique handle; replay and conflict rollback covered by pgTAP | **PASS** |
| RLS boundary matrix | anon, owner, other user, and moderator-shaped metadata covered by 31 assertions | **PASS** |
| Hosted Auth/RLS E2E | signup blocked; trusted user/login; owner account/onboarding; anon profile read | **PASS** |
| Reproducible install | `npm ci`: 755 installed, 756 audited, 0 vulnerabilities | **PASS** |
| Lint and strict typecheck | ESLint zero warnings; `tsc --noEmit` | **PASS** |
| Unit tests and coverage | 8 files, 33 tests; 92% statements, 93.54% branches, 84.61% functions, 93.61% lines | **PASS** |
| Next production build | Next.js `16.3.0`; all Identity routes and Edge middleware compiled | **PASS** |
| OpenNext Cloudflare build | OpenNext `1.20.2`; `.open-next/worker.js` generated | **PASS** |
| Workerd smoke | home/sign-in 200; account 307; health 200/no-store; CSP and frame denial present | **PASS** |
| Wrangler dry-run | Wrangler `4.120.0`; 37 assets; 7550.77 KiB raw / 1509.67 KiB gzip | **PASS** |
| Linked dry-run | `upToDate: true`; no pending migrations, seeds, or roles | **PASS** |
| Clean migration replay | guarded linked reset applied Phase 0, Phase 1, and repository seed only | **PASS** |
| Migration history | local and remote both contain `20260809001207` and `20260809033854` | **PASS** |
| Exact linked pgTAP | Docker-capable GitHub runner: 2 files, 35 tests, all successful | **PASS** |
| Supplemental linked pgTAP | all 31 Phase 1 assertions completed after the final clean replay | **PASS** |
| Database lint and advisors | no schema errors and no security/performance advisor findings | **PASS** |
| Security/RLS audit | 2 exposed tables, 2 with RLS, 6 explicit policies, fail-closed result | **PASS** |
| Deterministic fingerprint | repeated value `e0acaa89f8e3a80d3a55c8d082f0bc20`, object count 41 | **PASS** |
| Dashboard independence | replay required no manual schema or policy change in the dashboard | **PASS** |
| Git checkpoint | audited candidate published and promoted to a clean `main` checkpoint | **PASS** |

## Exact linked pgTAP evidence

The final required runner passed in GitHub Actions run
[`31294889151`](https://github.com/egin997/lingkar/actions/runs/31294889151), job `93198256318`,
against product commit `8b1ac8cb0c4ac4283f3c874ac155671ff3875acf`:

```text
supabase/tests/00_foundation.test.sql .. ok
supabase/tests/01_identity.test.sql ... ok
All tests successful.
Files=2, Tests=35, 15 wallclock secs
Result: PASS
Removed 2 deterministic Auth audit fixtures.
```

The restricted linked test role never writes to the protected `auth` schema. A trusted workflow
step provisions deterministic Auth users through the official Admin API, pgTAP exercises the
application roles and policies, and an `always()` cleanup step removes those exact users.

## Migration, RLS, and security audit

- `public.identity_accounts` is owner-only. `public.profiles` is the deliberately minimal public
  projection; neither table stores credentials, email, date of birth, or authorization claims.
- Every owner UPDATE policy targets `authenticated`, authorizes ownership with
  `(select auth.uid())`, and includes both `USING` and `WITH CHECK`.
- No policy uses deprecated `auth.role()` or user-editable `user_metadata`. Moderator-shaped app
  metadata grants no implicit private-account bypass.
- `public.complete_identity_onboarding(...)` is `SECURITY INVOKER`, derives the caller from Auth,
  normalizes the handle, and updates attestations/profile atomically and idempotently.
- The only privileged Identity function is the non-exposed Auth bootstrap trigger. It has an empty
  search path and no client execution privilege. No service-role key appears in client code.
- Neither migration nor pgTAP pins an extension version. The replay is compatible with the current
  Supabase behavior that manages extension versions without an explicit version clause.
- Advisors returned zero security and performance findings after the final replay.

## Hosted Auth and Cloudflare evidence

- Hosted settings confirmed public signup blocked, email login enabled, confirmation required,
  and anonymous Auth disabled. A trusted audit user could log in, received exactly one private
  account row, completed onboarding, and exposed only its minimal profile to an anonymous client.
- Next.js 16 Node Proxy is not yet supported by OpenNext Cloudflare `1.20.2`. The Auth refresh
  boundary intentionally uses the legacy Edge Middleware convention. Protected pages and Server
  Actions independently authorize access, so middleware is not the sole security boundary.
- The final OpenNext build, workerd route/header smoke, and Wrangler dry-run all passed. The smoke
  harness uses a cleared `AbortController` timer to avoid Node 26/Windows delayed-abort flakiness
  without weakening request timeouts or assertions.

## Gate decision

**Phase 1 — Identity: VERIFIED COMPLETE ✅**

**Phase 2 — Spaces & contextual reputation: UNLOCKED / NOT STARTED.** No Phase 2 implementation is
included in this checkpoint.
