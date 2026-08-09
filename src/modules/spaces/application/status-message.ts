const messages: Readonly<Record<string, string>> = {
  ban_failed: "Moderasi belum diterapkan. Periksa peran dan targetnya.",
  banned: "Anggota diban dari ruang ini dan akses aktifnya dicabut.",
  create_failed: "Ruang belum berhasil dibuat. Periksa slug atau coba lagi.",
  invalid_input: "Periksa kembali data ruang yang kamu masukkan.",
  invite_failed: "Undangan belum berhasil dibuat.",
  invited: "Undangan ruang berhasil dibuat.",
  join_failed: "Belum bisa bergabung ke ruang ini.",
  joined: "Kamu sudah menjadi anggota ruang ini.",
  left: "Kamu sudah keluar dari ruang ini.",
  moderation_failed: "Perubahan moderasi belum berhasil.",
  ownership_transferred: "Kepemilikan ruang berhasil dipindahkan.",
  reputation_updated: "Reputasi kontekstual berhasil diperbarui.",
  request_reviewed: "Permintaan bergabung sudah ditinjau.",
  requested: "Permintaan bergabung sudah masuk antrean moderator.",
  role_updated: "Peran anggota berhasil diperbarui.",
  rule_removed: "Aturan ruang berhasil dihapus.",
  rule_saved: "Aturan ruang berhasil disimpan.",
  unbanned: "Ban ruang berhasil dicabut.",
};

export function spaceStatusMessage(status: string | undefined): string | null {
  if (!status) return null;
  return messages[status] ?? null;
}
