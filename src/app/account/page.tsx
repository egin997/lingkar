import { redirect } from "next/navigation";

import { signOutAction } from "@/app/auth/actions";
import { identityStatusMessage } from "@/modules/identity/application/status-message";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";

import { updateProfileAction } from "./actions";

export const dynamic = "force-dynamic";

export default async function AccountPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const [params, viewer] = await Promise.all([searchParams, getViewerIdentity()]);

  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (!viewer.onboardingCompleted || !viewer.profile) redirect("/onboarding");

  return (
    <main className="auth-shell">
      <nav className="auth-nav" aria-label="Navigasi akun">
        <span className="wordmark">lingkar<span>.</span></span>
        <form action={signOutAction}><button className="button-secondary" type="submit">Keluar</button></form>
      </nav>
      <section className="auth-card wide" aria-labelledby="account-title">
        <p className="eyebrow">Akun closed beta</p>
        <h1 id="account-title">@{viewer.profile.handle}</h1>
        <p className="lede">Profil publikmu kecil dan sengaja minimal. Status usia dan persetujuan tetap privat.</p>
        {identityStatusMessage(params.status) ? (
          <p className="form-message" role="status">{identityStatusMessage(params.status)}</p>
        ) : null}
        <form className="auth-form" action={updateProfileAction}>
          <label htmlFor="handle">Handle</label>
          <div className="input-prefix"><span>@</span><input id="handle" name="handle" defaultValue={viewer.profile.handle} minLength={3} maxLength={30} pattern="[a-z][a-z0-9_]{2,29}" required /></div>
          <label htmlFor="displayName">Nama tampilan</label>
          <input id="displayName" name="displayName" defaultValue={viewer.profile.displayName} minLength={2} maxLength={50} required />
          <label htmlFor="bio">Bio singkat</label>
          <textarea id="bio" name="bio" defaultValue={viewer.profile.bio} maxLength={280} rows={5} />
          <button type="submit">Simpan profil</button>
        </form>
      </section>
    </main>
  );
}
