import Link from "next/link";

import { identityStatusMessage } from "@/modules/identity/application/status-message";

import { AuthShell } from "../_components/auth-shell";
import { requestRecoveryAction } from "../actions";

export const dynamic = "force-dynamic";

export default async function RecoveryPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const params = await searchParams;

  return (
    <AuthShell
      eyebrow="Pemulihan akun"
      title="Bikin password baru."
      description="Masukkan email undanganmu. Jawabannya selalu sama supaya status akun tetap privat."
      message={identityStatusMessage(params.status)}
    >
      <form className="auth-form" action={requestRecoveryAction}>
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" autoComplete="email" required />
        <button type="submit">Kirim tautan pemulihan</button>
      </form>
      <p className="form-footnote">
        <Link href="/auth/sign-in">Kembali ke halaman masuk</Link>
      </p>
    </AuthShell>
  );
}
