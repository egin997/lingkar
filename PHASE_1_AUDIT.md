# Phase 1 — Identity audit

Audit date: **2026-08-09 (Asia/Jakarta)**

Overall status: **VERIFICATION IN PROGRESS**

Phase 2 status: **LOCKED / NOT STARTED**

Phase 1 is not `VERIFIED COMPLETE` until the exact linked pgTAP runner and the final clean replay
both pass. This artifact records evidence without weakening that gate.

## Target and safety record

| Field | Evidence |
| --- | --- |
| Supabase CLI | `2.113.0`; command syntax rechecked with `--help` |
| Project ref | `nwiyakbolnumldkrvsim` |
| Environment | owner-confirmed disposable audit project in `ap-southeast-1` |
| Postgres | hosted `17.6` |
| Reset guard | exact ref + `disposable` + `RESET_DISPOSABLE_DATABASE_ONLY` |
| Secrets | no publishable, secret, legacy service-role, password, or token value is logged or committed |

## Acceptance evidence

| Criterion | Evidence | Result |
| --- | --- | --- |
| Invite-only Auth | hosted settings: global signup disabled, anonymous disabled, email provider enabled | **PASS** |
| Password and confirmation config | email confirmation on; strong password config pushed | **PASS** |
| SSR session refresh | `@supabase/ssr` cookie refresh propagates anti-cache headers | **PASS** |
| Auth routes | sign-in/out, confirm, recovery, update password, onboarding, account | **PASS** |
| 18+ privacy | versioned `18plus-v1`; no DOB/email/password columns in product identity tables | **PASS** |
| Atomic/idempotent onboarding | one transaction; normalized unique handle; conflict rollback and replay covered by pgTAP | **PASS (SQL direct)** |
| RLS boundaries | anon, owner, other-user, and moderator-metadata matrix covered by 31 pgTAP assertions | **PASS (SQL direct)** |
| Hosted Auth/RLS E2E | signup blocked; trusted user, password login, owner account, onboarding, anon profile read | **PASS** |
| Test cleanup | exact generated user IDs deleted through trusted admin API | **PASS** |
| Reproducible install | `npm ci`; 755 installed, 756 audited, 0 vulnerabilities | **PASS** |
| Lint/typecheck | ESLint zero warnings and strict `tsc --noEmit` | **PASS** |
| Unit tests/coverage | 8 files, 33 tests; 92% statements, 93.54% branches, 84.61% functions, 93.61% lines | **PASS** |
| Next production build | all Identity routes and session middleware compiled | **PASS** |
| OpenNext build | `.open-next/worker.js` generated | **PASS** |
| Workerd smoke | home/sign-in 200, protected account 307, health 200, security headers present | **PASS** |
| Wrangler dry-run | 37 assets; 7550.77 KiB raw / 1509.67 KiB gzip | **PASS** |
| Clean migration replay | Phase 0 and Phase 1 migrations replayed from empty disposable database | **PASS** |
| Migration list/dry-run | local/remote histories match; no pending migration, seed, or role | **PASS** |
| Database lint/advisors | no lint errors and no security/performance advisor findings | **PASS** |
| Security audit | 2 exposed tables, both RLS; 6 explicit policies; fail-closed audit PASS | **PASS** |
| Deterministic fingerprint | current fingerprint `e0acaa89f8e3a80d3a55c8d082f0bc20`, object count 41 | **PASS (first replay)** |
| Exact linked pgTAP runner | `supabase test db --linked` on Docker-capable runner | **PENDING** |
| Final replay + full rerun | required after exact pgTAP succeeds | **PENDING** |
| Git checkpoint | forbidden until every row passes | **LOCKED** |

## Security decisions

- Global signup is disabled while the email provider remains enabled; invitations are issued only
  by trusted operations using Supabase Admin APIs.
- `public.identity_accounts` is owner-only through RLS. `public.profiles` is the minimal public
  projection and stores no credential, email, date of birth, or authorization claim.
- Every owner UPDATE policy has both `USING` and `WITH CHECK`, targets `authenticated`, and derives
  ownership from `(select auth.uid())`.
- No policy uses deprecated `auth.role()` or user-editable `user_metadata`.
- Moderator-shaped app metadata provides no implicit Phase 1 bypass.
- The public onboarding RPC is `SECURITY INVOKER`; the only privileged identity function is the
  non-exposed Auth bootstrap trigger with an empty search path and no client execution privilege.
- No secret/service-role key appears in client code or a `NEXT_PUBLIC_*` variable.
- Extension versions are not pinned.

## Cloudflare compatibility resolution

Next.js 16 Node Proxy is not yet supported by OpenNext Cloudflare. The Auth refresh boundary uses
the legacy Edge Middleware convention intentionally; protected pages and Server Actions still
perform their own authorization, so middleware is not treated as the security boundary. OpenNext
build, workerd protected-route smoke, and Wrangler dry-run pass with this configuration.

## Remaining unlock condition

Run the exact linked pgTAP gate on the Docker-capable audit runner. If it passes, perform one more
guarded clean replay, verify the fingerprint is identical, rerun pgTAP/lint/advisors/security and the
complete application/Cloudflare suite, then update this artifact. Phase 2 remains locked until then.
