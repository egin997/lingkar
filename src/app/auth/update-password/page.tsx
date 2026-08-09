import { redirect } from "next/navigation";

import { identityStatusMessage } from "@/modules/identity/application/status-message";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";

import { AuthShell } from "../_components/auth-shell";
import { updatePasswordAction } from "../actions";

export const dynamic = "force-dynamic";

export default async function UpdatePasswordPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const [params, viewer] = await Promise.all([searchParams, getViewerIdentity()]);
  if (!viewer) redirect("/auth/sign-in?status=session_expired");

  return (
    <AuthShell
      eyebrow="Keamanan akun"
      title="Tentukan password baru."
      description="Gunakan minimal 10 karakter dengan huruf besar, kecil, angka, dan simbol."
      message={identityStatusMessage(params.status)}
    >
      <form className="auth-form" action={updatePasswordAction}>
        <label htmlFor="password">Password baru</label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="new-password"
          minLength={10}
          maxLength={72}
          required
        />
        <label htmlFor="passwordConfirmation">Ulangi password baru</label>
        <input
          id="passwordConfirmation"
          name="passwordConfirmation"
          type="password"
          autoComplete="new-password"
          minLength={10}
          maxLength={72}
          required
        />
        <button type="submit">Simpan password</button>
      </form>
    </AuthShell>
  );
}
