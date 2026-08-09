# Phase 3 — Content primitives audit

Audit date: **2026-08-09 (Asia/Jakarta)**

Overall status: **AUDIT CANDIDATE — exact linked CLI gate pending**

Phase 4 status: **LOCKED**

This document records the evidence gathered for Phase 3. The phase must not be marked
`VERIFIED COMPLETE` until the Docker-capable runner executes the exact
`supabase test db --linked` command against the authorized disposable project and the final
candidate remains green.

## Target and safety record

| Field | Evidence |
| --- | --- |
| Supabase CLI | `2.113.0`; reset, linked test, and lint syntax verified with `--help` |
| Project ref | `nwiyakbolnumldkrvsim` (non-secret identifier) |
| Environment | owner-confirmed disposable audit project; guarded destructive reset only |
| Postgres | hosted `17.6` |
| Reset guard | exact ref + `disposable` + `RESET_DISPOSABLE_DATABASE_ONLY` |
| Secrets | no key, password, token, or database credential logged or committed |

## Acceptance evidence

| Criterion | Command / evidence | Result |
| --- | --- | --- |
| Content formats | text, image, HTTPS link, poll, and Q&A implemented through one migration and trusted mutation boundary | **PASS** |
| Visibility and membership | public-space read, members-only read, private-space isolation, ban precedence, and active membership enforced in RLS/database functions | **PASS** |
| Media ownership | private 5 MiB `content-media` bucket, MIME allowlist, derived owner/asset path, four Storage policies | **PASS** |
| Revision and moderation lifecycle | post/reply revision snapshots, author soft-delete, moderator removal, hierarchy checks, immutable audit rows | **PASS** |
| Poll and Q&A invariants | validated single/multiple vote sets; only the question author can accept a reply from that question | **PASS** |
| Interaction primitives | same-space mentions, replies, reactions, private saves, accepted answer | **PASS** |
| Anti-spam foundation | transaction-scoped idempotency locks/receipts and database rate events/limits | **PASS** |
| Mutation boundary | browser table DML and mutation RPC execution denied; trusted server verifies SSR identity before service-only `SECURITY INVOKER` RPC | **PASS** |
| RLS/security matrix | 26 exposed tables, all 26 with RLS; 30 public policies; 4 Storage policies; fail-closed audit result | **PASS** |
| Deprecated authorization audit | no `auth.role()` or user-editable metadata in authorization; no extension version pinning | **PASS** |
| Migration replay | all four migrations replayed from an empty disposable database with no dashboard step | **PASS** |
| Migration history/dry-run | four local/remote versions match; linked dry-run reports up to date | **PASS** |
| Direct hosted pgTAP | 4 + 31 + 56 + 68 = 159 assertions executed through the linked SQL endpoint | **PASS** |
| Exact `supabase test db --linked` | Windows CLI confirmed syntax but requires Docker for `pg_prove`; Docker-capable GitHub run pending | **PENDING** |
| Database lint | linked `--level warning --fail-on error`; zero schema results | **PASS** |
| Database advisors | `--type all --level info --fail-on error`; no error-level finding; plan-gated Auth warnings recorded below | **PASS** |
| Deterministic fingerprint | repeated `38a07f9f89148e5a39b96e055e788c77`, repository object count `510` | **PASS** |
| Reproducible install | `npm ci`: 755 packages installed, 756 audited, zero vulnerabilities | **PASS** |
| Application gates | ESLint, strict TypeScript, 13 files / 49 tests, Next 16.3 production build | **PASS** |
| Unit coverage | 87.5% statements, 84.61% branches, 84.61% functions, 88.46% lines | **PASS** |
| OpenNext Cloudflare build | OpenNext 1.20.2 generated `.open-next/worker.js` | **PASS** |
| Workerd smoke | home/sign-in 200, account 307, health 200/no-store, CSP and frame denial present | **PASS** |
| Wrangler dry-run | Wrangler 4.120.0; 38 assets; 10369.13 KiB raw / 2011.77 KiB gzip | **PASS** |
| Hosted end-to-end flow | public read → join → text/poll/Q&A/image → vote/react/save/reply → accept answer → revision | **PASS** |
| Final audited checkpoint | candidate commit, exact linked run, clean main run, and tag | **PENDING** |

## Hosted end-to-end evidence

The browser run used real SSR cookies and the disposable Supabase project. It proved that a
non-member could read a public Space without mutation controls, an active member could join,
reply, and upload an image through Storage RLS, and the owner could accept the Q&A reply and edit a
post while retaining a revision. It also exercised poll voting, reactions, and private saves.
The run caught and fixed an unbounded reply-reaction query plus authentication ordering before
trusted profile lookup. Auth fixtures and all E2E data were removed by a guarded final reset.

## Advisor record

The `--fail-on error` advisor gate passed. A newly reset schema naturally reported unused-index
information. The disposable project also reports leaked-password protection and additional MFA
options as hosted Auth warnings; both remain production-plan launch gates already tracked for
Phase 5. Current reproducible controls retain invite-only signup, disabled anonymous auth,
confirmation, a 10-character minimum with all character classes, and secure password changes.

## Adapter compatibility record

Next 16.3 warns that the `middleware.ts` convention is deprecated in favor of `proxy.ts`.
OpenNext Cloudflare 1.20.2 currently rejects the generated Node proxy while accepting the Edge
middleware bundle. Phase 3 therefore retains `middleware.ts` deliberately; both the production
Next build and Cloudflare worker build pass. Migration to `proxy.ts` is blocked on adapter support,
not ignored as an application failure.

## Gate decision

**Phase 3 remains IN PROGRESS.**

**Phase 4 remains LOCKED** until the exact linked pgTAP runner and final checkpoint rows above are
replaced with verified evidence.
