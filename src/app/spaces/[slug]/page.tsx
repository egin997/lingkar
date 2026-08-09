import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { getContentStatusMessage } from "@/modules/content/application/status-message";
import { getSpaceContentFeed } from "@/modules/content/infrastructure/content";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";
import { spaceStatusMessage } from "@/modules/spaces/application/status-message";
import { getSpaceDetail } from "@/modules/spaces/infrastructure/spaces";

import { joinSpaceAction, leaveSpaceAction } from "../actions";
import { ContentComposer, ContentFeed } from "./_components/content";

export const dynamic = "force-dynamic";

export default async function SpacePage({
  params,
  searchParams,
}: {
  params: Promise<{ slug: string }>;
  searchParams: Promise<{ status?: string }>;
}) {
  const [{ slug }, query, viewer] = await Promise.all([params, searchParams, getViewerIdentity()]);
  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (!viewer.onboardingCompleted) redirect("/onboarding");
  const detail = await getSpaceDetail(slug, viewer.userId);
  if (!detail) notFound();
  const posts = await getSpaceContentFeed(detail.space.id, viewer.userId);
  const message = getContentStatusMessage(query.status) ?? spaceStatusMessage(query.status);
  const canManage = detail.viewerMembership?.role === "owner" || detail.viewerMembership?.role === "moderator";
  const hasPendingInvitation = detail.pendingInvitations.some(
    (invitation) => invitation.userId === viewer.userId,
  );

  return (
    <main className="community-shell">
      <nav className="community-nav">
        <Link className="wordmark" href="/spaces">lingkar<span>.</span></Link>
        <div className="community-nav-links">
          {canManage ? <Link href={`/spaces/${slug}/manage`}>Kelola</Link> : null}
          <Link href="/spaces">Semua ruang</Link>
        </div>
      </nav>

      <header className="space-hero">
        <div className="space-card-meta">
          <span>{detail.space.joinPolicy}</span>
          <span>{detail.space.discoverability}</span>
          <span>{detail.members.length} anggota</span>
        </div>
        <h1>{detail.space.name}</h1>
        <p className="lede">{detail.space.description || "Ruang ini belum menambahkan deskripsi."}</p>
        {message ? <p className="form-message" role="status">{message}</p> : null}
        {detail.viewerMembership ? (
          <div className="membership-actions">
            <span className="beta-pill">{detail.viewerMembership.role} · rep {detail.viewerMembership.reputation}</span>
            {detail.viewerMembership.role !== "owner" ? (
              <form action={leaveSpaceAction}>
                <input name="spaceId" type="hidden" value={detail.space.id} />
                <input name="slug" type="hidden" value={slug} />
                <button className="button-secondary" type="submit">Keluar ruang</button>
              </form>
            ) : null}
          </div>
        ) : (
          <form action={joinSpaceAction}>
            <input name="spaceId" type="hidden" value={detail.space.id} />
            <input name="slug" type="hidden" value={slug} />
            <button className="button-primary" type="submit">
              {hasPendingInvitation
                ? "Terima undangan"
                : detail.space.joinPolicy === "request"
                  ? "Minta bergabung"
                  : "Gabung ruang"}
            </button>
          </form>
        )}
      </header>

      <div className="space-columns">
        <section className="community-panel">
          <p className="eyebrow">Aturan ruang</p>
          <h2>Konteks yang disepakati</h2>
          {detail.rules.length ? (
            <ol className="rule-list">
              {detail.rules.map((rule) => (
                <li key={rule.id}>
                  <strong>{rule.title}</strong>
                  <p>{rule.body}</p>
                </li>
              ))}
            </ol>
          ) : <p className="muted">Moderator belum menulis aturan khusus.</p>}
        </section>
        <section className="community-panel">
          <p className="eyebrow">Anggota</p>
          <h2>Reputasi tinggal di konteksnya</h2>
          {detail.members.length ? (
            <ul className="member-list">
              {detail.members.map((member) => (
                <li key={member.userId}>
                  <div><strong>{member.displayName}</strong><small>@{member.handle} · {member.role}</small></div>
                  <span>{member.reputation}</span>
                </li>
              ))}
            </ul>
          ) : <p className="muted">Daftar anggota hanya terlihat dari dalam ruang.</p>}
        </section>
      </div>

      {detail.viewerMembership ? <ContentComposer slug={slug} spaceId={detail.space.id} /> : null}
      <header className="content-heading">
        <p className="eyebrow">Obrolan ruang</p>
        <h2>Konten dengan konteks, bukan keramaian.</h2>
      </header>
      <ContentFeed
        canInteract={Boolean(detail.viewerMembership)}
        canModerate={canManage}
        posts={posts}
        slug={slug}
        viewerId={viewer.userId}
      />
    </main>
  );
}
