const messages: Readonly<Record<string, string>> = {
  confirmation_failed: "Tautan konfirmasi tidak valid atau sudah kedaluwarsa.",
  handle_unavailable: "Handle itu sudah dipakai. Coba yang lain.",
  invalid_credentials: "Email atau password tidak cocok.",
  invalid_email: "Masukkan alamat email yang valid.",
  invalid_input: "Periksa kembali data yang kamu masukkan.",
  invalid_profile: "Profil belum valid. Periksa handle, nama, dan bio.",
  onboarding_complete: "Identitas kamu sudah siap.",
  onboarding_failed: "Onboarding belum berhasil. Coba lagi.",
  password_update_failed: "Password belum berhasil diperbarui.",
  password_updated: "Password berhasil diperbarui.",
  profile_update_failed: "Profil belum berhasil diperbarui.",
  profile_updated: "Profil berhasil diperbarui.",
  recovery_requested:
    "Kalau email terdaftar, tautan pemulihan akan segera dikirim.",
  session_expired: "Sesi kamu berakhir. Silakan masuk lagi.",
  signed_out: "Kamu sudah keluar.",
  weak_password: "Gunakan minimal 10 karakter dengan huruf besar, kecil, angka, dan simbol.",
};

export function identityStatusMessage(status: string | undefined): string | null {
  if (!status) return null;
  return messages[status] ?? null;
}
