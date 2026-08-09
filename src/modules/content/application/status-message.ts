const messages: Readonly<Record<string, string>> = {
  post_created: "Konten berhasil diterbitkan.",
  post_edited: "Perubahan konten tersimpan dan riwayat edit dicatat.",
  post_deleted: "Konten sudah dihapus.",
  reply_created: "Balasan berhasil dikirim.",
  reply_edited: "Balasan berhasil diperbarui.",
  reply_deleted: "Balasan sudah dihapus.",
  reaction_updated: "Reaksi diperbarui.",
  save_updated: "Status simpan diperbarui.",
  vote_recorded: "Pilihan poll berhasil dicatat.",
  answer_updated: "Jawaban terpilih diperbarui.",
  image_created: "Gambar berhasil diunggah dan diterbitkan.",
  invalid_content: "Konten belum valid. Periksa tipe, isi, link, pilihan, atau mention.",
  content_failed: "Konten belum dapat diproses. Coba lagi sebentar.",
  image_failed: "Gambar gagal diunggah. Gunakan JPG, PNG, WebP, atau GIF maksimal 5 MiB.",
  rate_limited: "Terlalu banyak aksi dalam waktu singkat. Tunggu sebentar lalu coba lagi.",
};

export function getContentStatusMessage(status?: string): string | null {
  if (!status) return null;
  return messages[status] ?? "Status konten tidak dikenali.";
}
