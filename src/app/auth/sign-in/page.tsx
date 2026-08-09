import Link from "next/link";

import { identityStatusMessage } from "@/modules/identity/application/status-message";
import { safeNextPath } from "@/shared/http/safe-next-path";

import { AuthShell } from "../_components/auth-shell";
import { signInAction } from "../actions";

export const dynamic = "force-dynamic";

export default async function SignInPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string; next?: string }>;
}) {
  const params = await searchParams;
  const next = safeNextPath(params.next ?? null, "/account");

  return (
    <AuthShell
      eyebrow="Closed beta"
      title="Masuk ke lingkaranmu."
      description="Akun dibuat lewat undangan. Belum punya undangan? Pendaftaran publik memang belum dibuka."
      message={identityStatusMessage(params.status)}
    >
      <form className="auth-form" action={signInAction}>
        <input type="hidden" name="next" value={next} />
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" autoComplete="email" required />
        <label htmlFor="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          autoComplete="current-password"
          maxLength={72}
          required
        />
        <button type="submit">Masuk</button>
      </form>
      <p className="form-footnote">
        Lupa password? <Link href="/auth/recovery">Pulihkan akun</Link>
      </p>
    </AuthShell>
  );
}
