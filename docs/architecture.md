# Arsitektur

LINGKAR memakai modular monolith: satu deployable Next.js dan satu Postgres Supabase, tetapi setiap
kapabilitas punya boundary internal yang eksplisit. Ini menjaga iterasi awal tetap cepat tanpa
mencampur aturan identity, spaces, content, reputation, feed, trust & safety, dan moderation.

Aliran dependensi setiap modul adalah `domain <- application <- infrastructure`; UI di `src/app`
hanya menjadi composition root. Modul tidak membaca tabel modul lain secara langsung. Integrasi
lintas modul dilakukan lewat application service atau kontrak event internal yang versioned.

Supabase Auth menjadi sumber identity teknis. Data produk berada di `public` dengan RLS wajib;
fungsi privileged berada di schema `private`, memakai `search_path = ''`, dan tidak executable oleh
`anon`/`authenticated` kecuali benar-benar diperlukan. `service_role` tidak pernah masuk browser.

Cloudflare Workers menjalankan output OpenNext dan menjadi edge/CDN/WAF layer. Respons auth atau
user-specific harus `private, no-store`; cache publik hanya boleh berisi data yang memang publik.

## Target modul

1. `identity` — invite, age attestation, profile, handle, session.
2. `spaces` — membership, roles, rules, contextual reputation.
3. `content` — text/image/link/poll/Q&A dan lifecycle moderation.
4. `feed` — controllable ranking/preferences dan explainability.
5. `trust-safety` — rate limits, spam/AI-slop signals, reports, appeals.
6. `moderation` — queues, case history, enforcement, audit log.

## Phase 1 identity boundary

Supabase Auth owns credentials, email confirmation, invitations, and sessions. Product tables never
store email, password, or date of birth. `public.identity_accounts` contains owner-only onboarding
state and versioned 18+/terms attestations; `public.profiles` is the deliberately small public
projection. Both tables enforce RLS and explicit grants.

`public.complete_identity_onboarding` is `SECURITY INVOKER`, derives ownership from `auth.uid()`, and
commits profile plus attestation in one transaction. The only privileged identity function is the
non-exposed `private.bootstrap_identity_account` Auth trigger. Client roles cannot execute it.

## Phase 2 spaces boundary

`spaces` owns room lifecycle, memberships, roles, rules, join requests, invitations, bans,
contextual-reputation ledger/balances, and moderation audit events. Ban precedence and ownership
transfer are transactional database invariants, not UI assumptions.

Browser roles receive RLS-filtered SELECT only. Public mutation RPCs are `SECURITY INVOKER`, denied
to `anon`/`authenticated`, and executable only from trusted server code after session and input
validation. The server passes the verified session user as `acting_user_id`; the Supabase secret
key is server-only. See [spaces.md](spaces.md) for the complete behavior and threat boundary.

## Phase 3 content boundary

`content` memiliki post, reply, media metadata, poll/Q&A, mention, reaction, save, revision, receipt
idempotensi, rate event, dan audit event. Bucket `content-media` bersifat privat; object path selalu
diturunkan dari user terverifikasi dan asset UUID. Browser hanya memperoleh SELECT yang disaring
RLS serta upload Storage yang dibatasi ownership untuk asset berstatus `staged`.

Semua mutasi konten melewati RPC `SECURITY INVOKER` yang hanya executable oleh `service_role`
setelah Server Action atau upload route memverifikasi session dan onboarding. Database mengambil
transaction-scoped advisory lock per idempotency key sebelum menghitung rate limit, sehingga retry
tidak menggandakan post, reply, vote, reaction, save, revision, ataupun audit event.
