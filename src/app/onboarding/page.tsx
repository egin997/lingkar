import { redirect } from "next/navigation";

import { signOutAction } from "@/app/auth/actions";
import { identityStatusMessage } from "@/modules/identity/application/status-message";
import {
  AGE_ATTESTATION_VERSION,
  TERMS_VERSION,
} from "@/modules/identity/domain/identity";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";

import { completeOnboardingAction } from "./actions";

export const dynamic = "force-dynamic";

export default async function OnboardingPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const [params, viewer] = await Promise.all([searchParams, getViewerIdentity()]);

  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (viewer.onboardingCompleted) redirect("/account");

  return (
    <main className="auth-shell">
      <nav className="auth-nav" aria-label="Navigasi onboarding">
        <span className="wordmark">lingkar<span>.</span></span>
        <form action={signOutAction}><button className="button-secondary" type="submit">Keluar</button></form>
      </nav>
      <section className="auth-card wide" aria-labelledby="onboarding-title">
        <p className="eyebrow">Identitas · langkah pertama</p>
        <h1 id="onboarding-title">Bikin ruang yang terasa seperti kamu.</h1>
        <p className="lede">
          Kami hanya meminta pernyataan 18+, bukan tanggal lahir. Versi persetujuan disimpan supaya
          perubahan aturan bisa diaudit dengan jelas.
        </p>
        {identityStatusMessage(params.status) ? (
          <p className="form-message" role="status">{identityStatusMessage(params.status)}</p>
        ) : null}
        <form className="auth-form" action={completeOnboardingAction}>
          <label htmlFor="handle">Handle</label>
          <div className="input-prefix"><span>@</span><input id="handle" name="handle" minLength={3} maxLength={30} pattern="[a-z][a-z0-9_]{2,29}" autoComplete="username" required /></div>
          <small>Huruf kecil, angka, dan garis bawah; mulai dengan huruf.</small>

          <label htmlFor="displayName">Nama tampilan</label>
          <input id="displayName" name="displayName" minLength={2} maxLength={50} autoComplete="name" required />

          <label className="check-row">
            <input name="adultAttestation" type="checkbox" required />
            <span>Saya menyatakan sudah berusia 18 tahun atau lebih. <small>{AGE_ATTESTATION_VERSION}</small></span>
          </label>
          <label className="check-row">
            <input name="termsAcceptance" type="checkbox" required />
            <span>Saya menyetujui aturan closed beta dan standar komunitas. <small>{TERMS_VERSION}</small></span>
          </label>
          <button type="submit">Selesaikan onboarding</button>
        </form>
      </section>
    </main>
  );
}
