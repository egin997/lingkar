import Link from "next/link";
import { redirect } from "next/navigation";

import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";
import { listVisibleSpaces } from "@/modules/spaces/infrastructure/spaces";
import { spaceStatusMessage } from "@/modules/spaces/application/status-message";

export const dynamic = "force-dynamic";

export default async function SpacesPage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const [viewer, params] = await Promise.all([getViewerIdentity(), searchParams]);
  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (!viewer.onboardingCompleted) redirect("/onboarding");
  const spaces = await listVisibleSpaces();
  const message = spaceStatusMessage(params.status);

  return (
    <main className="community-shell">
      <nav className="community-nav" aria-label="Navigasi komunitas">
        <Link className="wordmark" href="/">lingkar<span>.</span></Link>
        <div className="community-nav-links">
          <Link href="/account">@{viewer.profile?.handle}</Link>
          <Link className="button-primary compact" href="/spaces/new">Buat ruang</Link>
        </div>
      </nav>

      <header className="community-header">
        <p className="eyebrow">Spaces · reputasi kontekstual</p>
        <h1>Masuk karena topiknya. Bertahan karena orangnya.</h1>
        <p className="lede">Setiap ruang punya aturan, cara bergabung, moderator, dan reputasinya sendiri.</p>
        {message ? <p className="form-message" role="status">{message}</p> : null}
      </header>

      <section className="space-grid" aria-label="Daftar ruang">
        {spaces.length ? spaces.map((space) => (
          <article className="space-card" key={space.id}>
            <div className="space-card-meta">
              <span>{space.joinPolicy}</span>
              <span>{space.discoverability}</span>
            </div>
            <h2>{space.name}</h2>
            <p>{space.description || "Ruang baru yang sedang membentuk konteksnya."}</p>
            <Link href={`/spaces/${space.slug}`}>Lihat ruang →</Link>
          </article>
        )) : (
          <div className="empty-state">
            <p className="eyebrow">Belum ada ruang</p>
            <h2>Mulai lingkar pertama.</h2>
            <p>Buat ruang kecil dengan konteks yang jelas sebelum mengundang orang lain.</p>
            <Link className="button-primary" href="/spaces/new">Buat ruang</Link>
          </div>
        )}
      </section>
    </main>
  );
}
