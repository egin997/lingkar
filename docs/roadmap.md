# Roadmap dan acceptance criteria

Setiap phase wajib melalui `lint`, `typecheck`, unit test, Next build, Cloudflare adapter build,
`supabase db reset`, pgTAP, database lint, dan security review yang relevan. Phase berikutnya tidak
dimulai bila gate phase aktif gagal atau belum dapat dijalankan.

## Phase 0 — Foundation

Status: **VERIFIED COMPLETE ✅** — bukti lengkap ada di [`PHASE_0_AUDIT.md`](../PHASE_0_AUDIT.md).

- Repo + lockfile reproducible, strict TypeScript, lint/test/build scripts dan CI.
- Boundary modular monolith dan operational docs.
- Supabase config, migration workflow, private schema baseline dan pgTAP.
- Health endpoint, error surfaces, security headers, env contract.
- OpenNext + Wrangler config; adapter build berhasil.

## Phase 1 — Identity

Status: **IMPLEMENTED / VERIFICATION IN PROGRESS** — belum `VERIFIED COMPLETE`.

- Invite-only email/password auth dengan SSR cookie refresh.
- 18+ self-attestation yang versioned; tidak menyimpan tanggal lahir bila tidak diperlukan.
- Profile + normalized unique handle; onboarding atomic dan idempotent.
- RLS: public projection minimal, private self-read/write, explicit grants.
- Auth confirm, sign-in, sign-out, recovery, protected onboarding/account routes.
- Unit/integration/pgTAP tests membuktikan anon, owner, other-user, moderator boundaries.

## Phase 2 — Spaces & contextual reputation

Space lifecycle, membership/roles/rules, join controls, per-space reputation ledger dan moderation
baseline. Acceptance mencakup ownership transfer, ban precedence, dan auditability.

## Phase 3 — Content primitives

Text/image/link/poll/Q&A, media ownership, visibility, edit history, mentions, reaction/reply/save.
Semua mutation punya idempotency/rate limit dan test RLS lintas space.

## Phase 4 — Controllable feed

Following/topics/spaces feeds, chronological toggle, preference weights, mute/block, “why this post”,
dan pagination stabil. Ranking tidak memakai sensitive traits.

## Phase 5 — Trust, Safety & closed beta operations

Invite risk scoring, spam graph, AI-slop friction/labels, report/appeal queues, moderator case log,
retention/deletion workflow, abuse playbooks, dashboards, backup/restore drill, dan staged beta launch.
