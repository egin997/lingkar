# Spaces dan reputasi kontekstual

Phase 2 menjadikan ruang komunitas sebagai boundary sosial utama LINGKAR. Setiap ruang mempunyai
aturan, keanggotaan, peran, kontrol masuk, moderasi, dan reputasi yang tidak berlaku secara global.

## Kontrol bergabung

- `open`: pengguna terautentikasi dapat langsung menjadi anggota.
- `request`: pengguna masuk antrean dan owner/moderator harus menerima atau menolak.
- `invite`: hanya undangan aktif yang dapat dipakai untuk bergabung.

Undangan aktif merupakan jalur masuk eksplisit dan dapat diterima pada ruang open maupun request;
status undangan berubah menjadi `accepted` secara atomik. Tanpa undangan, kebijakan normal ruang
tetap berlaku.

Ban aktif selalu menang atas ketiga jalur tersebut. Membuat ban mencabut keanggotaan, membatalkan
permintaan, dan mencabut undangan tertunda dalam transaksi yang sama. Pencabutan ban tidak otomatis
memulihkan keanggotaan; pengguna harus bergabung kembali melalui kebijakan ruang yang berlaku.

## Peran dan ownership

Satu ruang aktif selalu mempunyai tepat satu owner. Owner dapat menunjuk moderator, menurunkan
moderator menjadi member, dan mentransfer ownership secara atomik. Moderator dapat meninjau
permintaan, mengundang, menulis aturan, mengubah reputasi, serta ban/unban anggota non-owner.
Semua keputusan menghasilkan audit event yang tidak bisa ditulis langsung oleh browser.

## Boundary keamanan

Browser hanya mendapat SELECT yang dibatasi RLS. Semua mutasi Phase 2 adalah fungsi
`SECURITY INVOKER` yang hanya executable oleh trusted server role. Next Server Actions memverifikasi
session dan onboarding, memvalidasi input, lalu memanggil fungsi tersebut memakai secret server
dan `acting_user_id` yang berasal dari session terverifikasi. Secret tidak pernah memakai prefix
`NEXT_PUBLIC_*`, masuk bundle browser, atau disimpan dalam tabel produk.

Tabel pada exposed schema memakai forced RLS. Policy tidak bergantung pada `auth.role()`,
`user_metadata`, atau klaim yang dapat diedit pengguna. Fungsi helper privileged tinggal di schema
`private`, memiliki `search_path = ''`, dan tidak menjadi API publik.

## Reputasi kontekstual

Reputasi disimpan sebagai ledger append-only per ruang. Setiap perubahan memiliki actor, target,
alasan, delta, dan request key idempoten. Balance adalah proyeksi turunan ledger, bukan skor global;
reputasi dari satu ruang tidak memberi wewenang di ruang lain.
