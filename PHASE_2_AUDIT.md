# Phase 2 — Spaces & contextual reputation audit

Audit date: **2026-08-09 (Asia/Jakarta)**

Overall status: **VERIFIED COMPLETE ✅**

Phase 3 status: **UNLOCKED / NOT STARTED**

Every mandatory application, Cloudflare, migration replay, exact linked pgTAP, database
lint/advisor, RLS/security, deterministic-schema, hosted E2E, and checkpoint gate passed without
lowering its acceptance criterion.

## Target and safety record

| Field | Evidence |
| --- | --- |
| Supabase CLI | `2.113.0`; linked reset, test, lint, and advisor syntax checked with `--help` |
| Project ref | `nwiyakbolnumldkrvsim` (non-secret identifier) |
| Environment | owner-confirmed disposable audit project in `ap-southeast-1` |
| Postgres | hosted `17.6` |
| Reset guard | exact ref + `disposable` + `RESET_DISPOSABLE_DATABASE_ONLY` |
| Secrets | no key, password, token, or database credential logged or committed |

## Acceptance evidence

| Criterion | Command / evidence | Result |
| --- | --- | --- |
| Space lifecycle and join modes | open, request, and invite paths implemented in one reproducible migration | **PASS** |
| Roles and ownership | owner/moderator/member plus atomic transfer and exactly-one-active-owner constraint | **PASS** |
| Ban precedence | active ban revokes membership/request/invite and blocks every join mode | **PASS** |
| Contextual reputation | append-only, per-space, actor/reason, idempotent request key, derived balance | **PASS** |
| Auditability | moderation mutations append non-client-writable audit events | **PASS** |
| RLS/security matrix | 11 exposed Phase 2 tables, 11 forced RLS, 15 policies; fail-closed audit | **PASS** |
| Mutation boundary | client DML/RPC denied; service-only `SECURITY INVOKER` RPC after verified server session | **PASS** |
| Deprecated authorization audit | no `auth.role()` or user-editable `user_metadata`; no extension version pin | **PASS** |
| Initial migration replay | Phase 0 + Phase 1 + Phase 2 replayed on empty disposable database | **PASS** |
| Direct hosted pgTAP evidence | all 56 Phase 2 assertions reached `finish`, including invitation precedence | **PASS** |
| Database lint | zero errors and warnings after replay | **PASS** |
| Database advisors | no security-definer/unindexed-FK error; plan-gated Auth warnings recorded below | **PASS** |
| Reproducible install | `npm ci`: 755 installed, 756 audited, zero vulnerabilities | **PASS** |
| Local lint/typecheck/unit/build | ESLint, strict TypeScript, 10 files/40 tests, Next production build | **PASS** |
| Final unit coverage | 92.64% statements, 94.28% branches, 82.35% functions, 93.75% lines | **PASS** |
| OpenNext Cloudflare build | OpenNext 1.20.2 generated `.open-next/worker.js` | **PASS** |
| Workerd smoke | home/sign-in 200; account 307; health 200/no-store; CSP and frame denial present | **PASS** |
| Wrangler dry-run | Wrangler 4.120.0; 37 assets; 9462.24 KiB raw / 1843.67 KiB gzip | **PASS** |
| Exact `supabase test db --linked` | final GitHub run `31300691175`: 3 files, 91 tests, all successful | **PASS** |
| Final clean replay | all three migrations, seed, matching history, and up-to-date dry-run | **PASS** |
| Repeated deterministic fingerprint | repeated `09b4f735504c0e134b48759240b45233`, object count 226 | **PASS** |
| Hosted app end-to-end flow | onboarding → create → request/review → reputation → ban/unban → invite/accept | **PASS** |
| Audited candidate checkpoint | commit `91c07a86c30d8a5fc98e4e0e67089324f05714a4` published with green CI | **PASS** |
| Main promotion checkpoint | audited history fast-forwarded to `main`; tag `phase-2-verified` | **PASS** |

## Advisor record

The final `--fail-on error` advisor gate passed. It reported only unused-index information expected
for a newly reset schema plus two hosted Auth warnings: leaked-password protection and additional
MFA options. Supabase documents both capabilities as Pro-plan features. The disposable audit
project is not promoted as production; enabling both remains a production-plan launch gate in
Phase 5. Current reproducible Auth controls still enforce invite-only signup, confirmation,
10-character minimum, all character classes, secure password changes, and disabled anonymous auth.

## Hosted end-to-end evidence

The final disposable-project browser run verified real SSR sessions and Server Actions. It caught
and resolved two issues before candidate publication: a UI query assumed a nonexistent scalar ban
ID instead of the composite key, and invitations did not originally override request gating. The
final run proved direct invitation acceptance while retaining ban precedence, contextual score,
and auditable moderation behavior. A guarded reset removed all hosted E2E data and Auth fixtures.

## Exact linked pgTAP evidence

The Docker-capable GitHub Actions
[run `31300691175`](https://github.com/egin997/lingkar/actions/runs/31300691175), job
`93212863161`, tested final candidate commit `91c07a86c30d8a5fc98e4e0e67089324f05714a4`:

```text
supabase/tests/00_foundation.test.sql .. ok
supabase/tests/01_identity.test.sql .... ok
supabase/tests/02_spaces.test.sql ...... ok
All tests successful.
Files=3, Tests=91, 31 wallclock secs
Result: PASS
Removed 4 deterministic Auth audit fixtures.
```

After that runner completed, the guarded linked reset replayed all three migrations from empty,
the linked dry-run was up to date, database lint returned no errors, the RLS audit returned PASS,
and fingerprint `09b4f735504c0e134b48759240b45233` repeated with 226 repository objects.

## Gate decision

**Phase 2 — Spaces & contextual reputation: VERIFIED COMPLETE ✅**

**Phase 3 — Content primitives: UNLOCKED / NOT STARTED.**
