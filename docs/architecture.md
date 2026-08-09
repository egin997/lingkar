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
