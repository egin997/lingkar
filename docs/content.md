# Content primitives

Phase 3 menambahkan post bertipe text, image, link, poll, dan Q&A di dalam Space. Konten tetap
community-first: penulis wajib anggota aktif, ban Space selalu menang, dan visibility `members`
tidak dapat dibaca non-member walaupun Space bersifat public.

## Lifecycle dan transparency

- Post/reply dihapus secara soft-delete; moderator memakai status `removed` dengan actor tercatat.
- Edit body, link, atau visibility menyimpan snapshot sebelumnya di revision append-only.
- Q&A menyimpan accepted reply; hanya penanya yang dapat memilih atau mencabut jawaban.
- Mention hanya dapat menunjuk anggota aktif di Space yang sama.
- Save bersifat privat untuk pemilik; vote bersifat voter/moderator-only, sementara total poll
  diproyeksikan pada option tanpa membuka identitas voter.

## Media

Bucket `content-media` private dan dibuat melalui migration. Asset diregistrasikan lebih dahulu
dengan UUID, MIME allowlist, batas 5 MiB, dan object path `user-id/asset-id/filename`. Storage RLS
hanya mengizinkan owner mengunggah atau mengganti asset staged miliknya. Setelah post image dibuat,
asset menjadi attached dan pembaca hanya dapat mengambil signed URL bila RLS post mengizinkannya.

## Mutation boundary

Browser tidak mendapat INSERT/UPDATE/DELETE pada tabel Phase 3 dan tidak dapat mengeksekusi RPC
mutasi. Server memverifikasi session/onboarding, memvalidasi input dengan Zod, lalu memanggil RPC
`SECURITY INVOKER` menggunakan credential server-only. Semua RPC meminta UUID idempotensi,
mengambil advisory transaction lock, mengembalikan receipt lama pada retry, dan menghitung rate
event sebelum menulis domain data.

## Acceptance criteria

- Reproducible migration replay menciptakan 15 tabel public dengan forced RLS serta bucket private.
- Text/image/link/poll/Q&A, edit history, mention, reply, reaction, save, vote, dan accepted answer
  mempunyai bukti pgTAP positif dan negatif.
- RLS membuktikan public-space, members-only, private-space, owner, other-user, dan moderator matrix.
- Media path tidak berasal dari input client dan upload Storage tunduk pada owner + staged status.
- Retry tidak menggandakan row/rate event; reuse key pada operasi berbeda gagal tertutup.
- Rate limit database menolak operasi di atas kuota dan tidak dapat dilewati dari browser.
- Lint, strict typecheck, unit coverage, Next build, OpenNext, workerd, Wrangler, linked pgTAP,
  database lint/advisors, RLS/security audit, fingerprint, dan hosted E2E semuanya PASS.
