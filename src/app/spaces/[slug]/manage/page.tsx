import Link from "next/link";
import { notFound, redirect } from "next/navigation";

import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";
import { spaceStatusMessage } from "@/modules/spaces/application/status-message";
import { getSpaceDetail } from "@/modules/spaces/infrastructure/spaces";

import {
  banMemberAction,
  changeReputationAction,
  inviteMemberAction,
  removeSpaceRuleAction,
  reviewJoinRequestAction,
  saveSpaceRuleAction,
  setMemberRoleAction,
  transferOwnershipAction,
  unbanMemberAction,
} from "../../actions";

export default async function ManageSpacePage({
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
  const viewerRole = detail.viewerMembership?.role;
  if (viewerRole !== "owner" && viewerRole !== "moderator") redirect(`/spaces/${slug}`);
  const message = spaceStatusMessage(query.status);

  return (
    <main className="community-shell">
      <nav className="community-nav">
        <Link className="wordmark" href={`/spaces/${slug}`}>lingkar<span>.</span></Link>
        <Link href={`/spaces/${slug}`}>Kembali ke ruang</Link>
      </nav>
      <header className="community-header compact-header">
        <p className="eyebrow">Moderation baseline · {viewerRole}</p>
        <h1>Kelola {detail.space.name}</h1>
        <p className="lede">Setiap keputusan di bawah menghasilkan audit event yang tidak bisa ditulis langsung oleh browser.</p>
        {message ? <p className="form-message" role="status">{message}</p> : null}
      </header>

      <div className="manage-grid">
        <section className="community-panel">
          <p className="eyebrow">Join requests</p>
          <h2>Antrean masuk</h2>
          {detail.pendingRequests.length ? detail.pendingRequests.map((request) => (
            <div className="moderation-row" key={request.id}>
              <div><strong>{request.displayName}</strong><small>@{request.handle}</small></div>
              <form action={reviewJoinRequestAction}>
                <input name="requestId" type="hidden" value={request.id} />
                <input name="slug" type="hidden" value={slug} />
                <button name="decision" value="approved" type="submit">Terima</button>
                <button className="button-secondary" name="decision" value="rejected" type="submit">Tolak</button>
              </form>
            </div>
          )) : <p className="muted">Tidak ada permintaan tertunda.</p>}
        </section>

        <section className="community-panel">
          <p className="eyebrow">Invitations</p>
          <h2>Undang lewat handle</h2>
          <form className="auth-form compact-form" action={inviteMemberAction}>
            <input name="spaceId" type="hidden" value={detail.space.id} />
            <input name="slug" type="hidden" value={slug} />
            <label htmlFor="invite-handle">Handle anggota</label>
            <input id="invite-handle" name="handle" pattern="[a-z0-9_]{3,24}" placeholder="nama_pengguna" required />
            <button type="submit">Kirim undangan 7 hari</button>
          </form>
          {detail.pendingInvitations.map((invitation) => (
            <div className="moderation-row" key={invitation.id}>
              <div>
                <strong>{invitation.displayName}</strong>
                <small>@{invitation.handle} · aktif sampai {new Intl.DateTimeFormat("id-ID", { dateStyle: "medium" }).format(new Date(invitation.expiresAt))}</small>
              </div>
            </div>
          ))}
        </section>

        <section className="community-panel">
          <p className="eyebrow">Rules</p>
          <h2>Tulis aturan</h2>
          <form className="auth-form compact-form" action={saveSpaceRuleAction}>
            <input name="spaceId" type="hidden" value={detail.space.id} />
            <input name="slug" type="hidden" value={slug} />
            <input name="ruleId" type="hidden" value="" />
            <label htmlFor="position">Urutan</label>
            <input id="position" name="position" min={1} max={50} type="number" required />
            <label htmlFor="title">Judul</label>
            <input id="title" name="title" minLength={3} maxLength={100} required />
            <label htmlFor="body">Isi aturan</label>
            <textarea id="body" name="body" minLength={3} maxLength={1000} rows={4} required />
            <label className="check-row"><input defaultChecked name="isRequired" type="checkbox" /><span>Wajib dipatuhi</span></label>
            <button type="submit">Tambah aturan</button>
          </form>
          {detail.rules.map((rule) => (
            <div className="moderation-row rule-row" key={rule.id}>
              <div><strong>{rule.position}. {rule.title}</strong><small>{rule.body}</small></div>
              <form action={removeSpaceRuleAction}>
                <input name="spaceId" type="hidden" value={detail.space.id} />
                <input name="slug" type="hidden" value={slug} />
                <input name="ruleId" type="hidden" value={rule.id} />
                <button className="button-secondary" type="submit">Hapus</button>
              </form>
            </div>
          ))}
        </section>
      </div>

      <section className="community-panel member-admin-panel">
        <p className="eyebrow">Members & contextual reputation</p>
        <h2>Wewenang tinggal di ruang ini</h2>
        <div className="member-admin-list">
          {detail.members.map((member) => (
            <article className="member-admin-card" key={member.userId}>
              <header><div><strong>{member.displayName}</strong><small>@{member.handle}</small></div><span>{member.role} · {member.reputation}</span></header>
              {member.userId !== viewer.userId && member.role !== "owner" ? (
                <>
                  {viewerRole === "owner" ? (
                    <form action={setMemberRoleAction}>
                      <input name="spaceId" type="hidden" value={detail.space.id} />
                      <input name="slug" type="hidden" value={slug} />
                      <input name="userId" type="hidden" value={member.userId} />
                      <select name="role" defaultValue={member.role === "moderator" ? "moderator" : "member"}><option value="member">Member</option><option value="moderator">Moderator</option></select>
                      <button type="submit">Ubah peran</button>
                    </form>
                  ) : null}
                  <form action={changeReputationAction}>
                    <input name="spaceId" type="hidden" value={detail.space.id} />
                    <input name="slug" type="hidden" value={slug} />
                    <input name="userId" type="hidden" value={member.userId} />
                    <input aria-label={`Perubahan reputasi ${member.handle}`} name="delta" max={100} min={-100} placeholder="+5 / -5" required type="number" />
                    <input aria-label={`Alasan reputasi ${member.handle}`} name="reason" maxLength={200} placeholder="Alasan kontekstual" required />
                    <button type="submit">Catat reputasi</button>
                  </form>
                  <form action={banMemberAction}>
                    <input name="spaceId" type="hidden" value={detail.space.id} />
                    <input name="slug" type="hidden" value={slug} />
                    <input name="userId" type="hidden" value={member.userId} />
                    <input aria-label={`Alasan ban ${member.handle}`} name="reason" maxLength={500} placeholder="Alasan ban" required />
                    <button className="button-danger" type="submit">Ban dari ruang</button>
                  </form>
                  {viewerRole === "owner" ? (
                    <form action={transferOwnershipAction}>
                      <input name="spaceId" type="hidden" value={detail.space.id} />
                      <input name="slug" type="hidden" value={slug} />
                      <input name="userId" type="hidden" value={member.userId} />
                      <button className="button-secondary" type="submit">Transfer ownership</button>
                    </form>
                  ) : null}
                </>
              ) : null}
            </article>
          ))}
        </div>
      </section>


      <section className="community-panel member-admin-panel">
        <p className="eyebrow">Active bans</p>
        <h2>Ban yang sedang berlaku</h2>
        {detail.activeBans.length ? detail.activeBans.map((ban) => (
          <div className="moderation-row" key={ban.userId}>
            <div>
              <strong>{ban.displayName}</strong>
              <small>@{ban.handle} · {ban.reason}</small>
            </div>
            <form action={unbanMemberAction}>
              <input name="spaceId" type="hidden" value={detail.space.id} />
              <input name="slug" type="hidden" value={slug} />
              <input name="userId" type="hidden" value={ban.userId} />
              <button className="button-secondary" type="submit">Cabut ban</button>
            </form>
          </div>
        )) : <p className="muted">Tidak ada ban aktif.</p>}
      </section>
    </main>
  );
}
