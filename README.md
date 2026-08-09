# LINGKAR

Community-first social network untuk Indonesia. Produk dirancang sebagai closed beta 18+ dengan
feed yang bisa dikontrol, reputasi kontekstual, moderasi kuat, dan proteksi anti-spam/AI-slop.

Status saat ini: **Phase 0 — Foundation: VERIFIED COMPLETE ✅**. Phase 1 — Identity sudah
diimplementasikan dan sedang melalui audit; belum boleh disebut selesai sebelum seluruh gate PASS.

## Menjalankan aplikasi

Prasyarat: Node.js 22 LTS, npm 11, dan Docker-compatible runtime untuk Supabase lokal.

```bash
cp .env.example .env.local
npm ci
npm run db:start
npm run db:reset
npm run dev
```

Quality gates:

```bash
npm run check
npm run db:test
npm run db:lint
npm run cf:build
npm run cf:smoke
npm run cf:dry-run
```

Jangan pernah menaruh Supabase secret key atau `service_role` di variabel `NEXT_PUBLIC_*`.

## Struktur

- `src/app` — routing dan composition root Next.js.
- `src/modules/<domain>` — boundary domain/application/infrastructure per modul.
- `src/shared` — primitive lintas modul yang benar-benar generik.
- `supabase/migrations` — satu-satunya sumber perubahan schema, berurutan dan versioned.
- `supabase/tests` — pgTAP untuk schema, privilege, dan RLS.
- `docs` — arsitektur, roadmap, environment, deployment, dan audit phase.

Lihat [roadmap](docs/roadmap.md) dan [audit Phase 0](PHASE_0_AUDIT.md).
