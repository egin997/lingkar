import Link from "next/link";
import { redirect } from "next/navigation";

import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";
import { spaceStatusMessage } from "@/modules/spaces/application/status-message";

import { createSpaceAction } from "../actions";

export default async function NewSpacePage({
  searchParams,
}: {
  searchParams: Promise<{ status?: string }>;
}) {
  const [viewer, params] = await Promise.all([getViewerIdentity(), searchParams]);
  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (!viewer.onboardingCompleted) redirect("/onboarding");
  const message = spaceStatusMessage(params.status);

  return (
    <main className="auth-shell">
      <nav className="auth-nav">
        <Link className="wordmark" href="/spaces">lingkar<span>.</span></Link>
        <Link href="/spaces">Batal</Link>
      </nav>
      <section className="auth-card wide" aria-labelledby="new-space-title">
        <p className="eyebrow">Ruang baru</p>
        <h1 id="new-space-title">Beri konteks sebelum mengundang keramaian.</h1>
        <p className="lede">Slug tidak bisa dipakai ruang lain. Kebijakan bergabung bisa dikembangkan setelah komunitas tumbuh.</p>
        {message ? <p className="form-message" role="status">{message}</p> : null}
        <form className="auth-form" action={createSpaceAction}>
          <label htmlFor="name">Nama ruang</label>
          <input id="name" name="name" minLength={3} maxLength={80} required />
          <label htmlFor="slug">Slug</label>
          <div className="input-prefix"><span>/</span><input id="slug" name="slug" pattern="[a-z][a-z0-9-]{2,47}" required /></div>
          <small>Huruf kecil, angka, dan tanda hubung. Contoh: ngoprek-bareng.</small>
          <label htmlFor="description">Deskripsi</label>
          <textarea id="description" name="description" maxLength={1000} rows={5} />
          <label htmlFor="joinPolicy">Cara bergabung</label>
          <select id="joinPolicy" name="joinPolicy" defaultValue="request">
            <option value="open">Terbuka</option>
            <option value="request">Perlu persetujuan</option>
            <option value="invite">Hanya undangan</option>
          </select>
          <label htmlFor="discoverability">Penemuan</label>
          <select id="discoverability" name="discoverability" defaultValue="public">
            <option value="public">Publik</option>
            <option value="unlisted">Tidak terdaftar</option>
            <option value="private">Privat</option>
          </select>
          <button type="submit">Buat ruang</button>
        </form>
      </section>
    </main>
  );
}
