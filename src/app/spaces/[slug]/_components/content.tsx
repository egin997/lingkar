import { randomUUID } from "node:crypto";

import Image from "next/image";

import type { ContentPost, ContentReply } from "@/modules/content/infrastructure/content";

import {
  acceptContentAnswerAction,
  createContentPostAction,
  createContentReplyAction,
  deleteContentPostAction,
  deleteContentReplyAction,
  editContentPostAction,
  editContentReplyAction,
  setContentReactionAction,
  setContentSavedAction,
  voteContentPollAction,
} from "../../content-actions";

const dateFormatter = new Intl.DateTimeFormat("id-ID", {
  dateStyle: "medium",
  timeStyle: "short",
  timeZone: "Asia/Jakarta",
});

function HiddenContext({ slug, postId }: { slug: string; postId?: number }) {
  return (
    <>
      <input name="slug" type="hidden" value={slug} />
      {postId ? <input name="postId" type="hidden" value={postId} /> : null}
      <input name="requestKey" type="hidden" value={randomUUID()} />
    </>
  );
}

export function ContentComposer({ spaceId, slug }: { spaceId: number; slug: string }) {
  return (
    <section className="content-composer community-panel" id="content">
      <p className="eyebrow">Tulis dengan konteks</p>
      <h2>Mulai obrolan di ruang ini</h2>
      <form className="auth-form content-form" action={createContentPostAction}>
        <input name="spaceId" type="hidden" value={spaceId} />
        <HiddenContext slug={slug} />
        <div className="content-form-row">
          <label htmlFor="kind">Format</label>
          <select defaultValue="text" id="kind" name="kind">
            <option value="text">Teks</option>
            <option value="link">Link</option>
            <option value="poll">Poll</option>
            <option value="question">Q&amp;A</option>
          </select>
          <label htmlFor="visibility">Visibility</label>
          <select defaultValue="space" id="visibility" name="visibility">
            <option value="space">Semua yang bisa melihat ruang</option>
            <option value="members">Hanya anggota aktif</option>
          </select>
        </div>
        <label htmlFor="body">Isi</label>
        <textarea id="body" maxLength={10000} name="body" required rows={5} />
        <label htmlFor="linkUrl">Link HTTPS <small>khusus format Link</small></label>
        <input id="linkUrl" maxLength={2048} name="linkUrl" placeholder="https://..." type="url" />
        <fieldset className="poll-builder">
          <legend>Pilihan poll <small>isi minimal dua bila format Poll</small></legend>
          {[1, 2, 3, 4].map((position) => (
            <input
              aria-label={`Pilihan poll ${position}`}
              key={position}
              maxLength={120}
              name="pollOption"
              placeholder={`Pilihan ${position}`}
            />
          ))}
          <label className="check-row">
            <input name="pollAllowsMultiple" type="checkbox" />
            <span>Boleh memilih lebih dari satu</span>
          </label>
        </fieldset>
        <label htmlFor="mentions">Mention anggota</label>
        <input id="mentions" name="mentions" placeholder="@yun, @ara" />
        <button type="submit">Terbitkan konten</button>
      </form>

      <details className="image-composer">
        <summary>Terbitkan gambar dari perangkat</summary>
        <form action="/api/content/image" encType="multipart/form-data" method="post" className="auth-form">
          <input name="spaceId" type="hidden" value={spaceId} />
          <input name="slug" type="hidden" value={slug} />
          <input name="assetId" type="hidden" value={randomUUID()} />
          <input name="registerRequestKey" type="hidden" value={randomUUID()} />
          <input name="requestKey" type="hidden" value={randomUUID()} />
          <label htmlFor="image">Gambar</label>
          <input accept="image/jpeg,image/png,image/webp,image/gif" id="image" name="image" required type="file" />
          <small>JPG, PNG, WebP, atau GIF. Maksimal 5 MiB.</small>
          <label htmlFor="imageBody">Keterangan</label>
          <textarea id="imageBody" maxLength={10000} name="body" rows={3} />
          <label htmlFor="imageVisibility">Visibility</label>
          <select defaultValue="space" id="imageVisibility" name="visibility">
            <option value="space">Semua yang bisa melihat ruang</option>
            <option value="members">Hanya anggota aktif</option>
          </select>
          <label htmlFor="imageMentions">Mention anggota</label>
          <input id="imageMentions" name="mentions" placeholder="@yun, @ara" />
          <button type="submit">Unggah dan terbitkan</button>
        </form>
      </details>
    </section>
  );
}

function ReactionForm({
  slug,
  targetType,
  targetId,
  current,
}: {
  slug: string;
  targetType: "post" | "reply";
  targetId: number;
  current: string | null;
}) {
  return (
    <form action={setContentReactionAction} className="inline-action">
      <input name="slug" type="hidden" value={slug} />
      <input name="targetType" type="hidden" value={targetType} />
      <input name="targetId" type="hidden" value={targetId} />
      <input name="requestKey" type="hidden" value={randomUUID()} />
      <select aria-label="Pilih reaksi" defaultValue={current ?? "apresiasi"} name="reaction">
        <option value="apresiasi">Apresiasi</option>
        <option value="membantu">Membantu</option>
        <option value="menarik">Menarik</option>
        {current ? <option value="removed">Hapus reaksi</option> : null}
      </select>
      <button className="button-secondary" type="submit">Reaksi</button>
    </form>
  );
}

function ReplyCard({
  reply,
  post,
  slug,
  viewerId,
  canModerate,
}: {
  reply: ContentReply;
  post: ContentPost;
  slug: string;
  viewerId: string;
  canModerate: boolean;
}) {
  const isAuthor = reply.authorId === viewerId;
  const accepted = post.acceptedReplyId === reply.id;
  return (
    <article className={`reply-card${accepted ? " accepted" : ""}`}>
      <header>
        <div><strong>{reply.displayName}</strong><small>@{reply.handle}</small></div>
        <span>{dateFormatter.format(new Date(reply.createdAt))}{reply.editedAt ? " · diedit" : ""}</span>
      </header>
      <p>{reply.body}</p>
      <div className="content-actions">
        {accepted ? <span className="accepted-pill">Jawaban diterima</span> : null}
        <ReactionForm current={reply.viewerReaction} slug={slug} targetId={reply.id} targetType="reply" />
        {post.kind === "question" && post.authorId === viewerId ? (
          <form action={acceptContentAnswerAction}>
            <HiddenContext postId={post.id} slug={slug} />
            <input name="replyId" type="hidden" value={accepted ? "" : reply.id} />
            <button className="button-secondary" type="submit">{accepted ? "Cabut jawaban" : "Terima jawaban"}</button>
          </form>
        ) : null}
      </div>
      {isAuthor ? (
        <details className="edit-panel">
          <summary>Edit balasan</summary>
          <form action={editContentReplyAction} className="auth-form compact-content-form">
            <input name="replyId" type="hidden" value={reply.id} />
            <HiddenContext slug={slug} />
            <label htmlFor={`edit-reply-body-${reply.id}`}>Isi balasan</label>
            <textarea
              defaultValue={reply.body}
              id={`edit-reply-body-${reply.id}`}
              maxLength={5000}
              name="body"
              required
              rows={3}
            />
            <label htmlFor={`edit-reply-mentions-${reply.id}`}>Mention anggota</label>
            <input id={`edit-reply-mentions-${reply.id}`} name="mentions" placeholder="@handle, @handle" />
            <button type="submit">Simpan edit</button>
          </form>
        </details>
      ) : null}
      {isAuthor || canModerate ? (
        <form action={deleteContentReplyAction} className="danger-action">
          <input name="replyId" type="hidden" value={reply.id} />
          <HiddenContext slug={slug} />
          <button className="button-danger" type="submit">{isAuthor ? "Hapus balasan" : "Moderasi balasan"}</button>
        </form>
      ) : null}
    </article>
  );
}

function PostCard({
  post,
  slug,
  viewerId,
  canModerate,
}: {
  post: ContentPost;
  slug: string;
  viewerId: string;
  canModerate: boolean;
}) {
  const isAuthor = post.authorId === viewerId;
  const reactionSummary = Object.entries(post.reactions)
    .map(([reaction, count]) => `${reaction} ${count}`)
    .join(" · ");
  return (
    <article className="content-card" id={`post-${post.id}`}>
      <header className="content-card-header">
        <div>
          <strong>{post.displayName}</strong>
          <small>@{post.handle} · {post.kind} · {post.visibility}</small>
        </div>
        <span>{dateFormatter.format(new Date(post.createdAt))}{post.editedAt ? " · diedit" : ""}</span>
      </header>
      <p className="content-body">{post.body}</p>
      {post.linkUrl ? <a className="link-preview" href={post.linkUrl} rel="noreferrer" target="_blank">{post.linkUrl}</a> : null}
      {post.media.map((media) => media.signedUrl ? (
        <Image
          alt={post.body || media.filename}
          className="content-image"
          height={900}
          key={media.id}
          src={media.signedUrl}
          unoptimized
          width={1200}
        />
      ) : <p className="muted" key={media.id}>Gambar belum tersedia.</p>)}
      {post.poll ? (
        <form action={voteContentPollAction} className="poll-card">
          <HiddenContext postId={post.id} slug={slug} />
          {post.poll.options.map((option) => (
            <label key={option.id}>
              <input
                defaultChecked={option.selectedByViewer}
                name="optionId"
                type={post.poll?.allowsMultiple ? "checkbox" : "radio"}
                value={option.id}
              />
              <span>{option.label}</span>
              <strong>{option.voteCount}</strong>
            </label>
          ))}
          <button className="button-secondary" type="submit">Catat pilihan</button>
        </form>
      ) : null}
      <div className="content-actions">
        <ReactionForm current={post.viewerReaction} slug={slug} targetId={post.id} targetType="post" />
        <form action={setContentSavedAction}>
          <HiddenContext postId={post.id} slug={slug} />
          <input name="saved" type="hidden" value={post.viewerSaved ? "false" : "true"} />
          <button className="button-secondary" type="submit">{post.viewerSaved ? "Batal simpan" : "Simpan"}</button>
        </form>
        {reactionSummary ? <small>{reactionSummary}</small> : null}
        {post.revisionCount ? <small>{post.revisionCount} revisi</small> : null}
      </div>

      {isAuthor ? (
        <details className="edit-panel">
          <summary>Edit post</summary>
          <form action={editContentPostAction} className="auth-form compact-content-form">
            <HiddenContext postId={post.id} slug={slug} />
            <label htmlFor={`edit-post-body-${post.id}`}>Isi post</label>
            <textarea
              defaultValue={post.body}
              id={`edit-post-body-${post.id}`}
              maxLength={10000}
              name="body"
              rows={4}
            />
            <label htmlFor={`edit-post-link-${post.id}`}>Link HTTPS</label>
            <input
              defaultValue={post.linkUrl ?? ""}
              id={`edit-post-link-${post.id}`}
              name="linkUrl"
              placeholder="https://... bila post link"
              type="url"
            />
            <label htmlFor={`edit-post-visibility-${post.id}`}>Visibility</label>
            <select defaultValue={post.visibility} id={`edit-post-visibility-${post.id}`} name="visibility">
              <option value="space">Semua yang bisa melihat ruang</option>
              <option value="members">Hanya anggota aktif</option>
            </select>
            <label htmlFor={`edit-post-mentions-${post.id}`}>Mention anggota</label>
            <input id={`edit-post-mentions-${post.id}`} name="mentions" placeholder="@handle, @handle" />
            <button type="submit">Simpan dengan riwayat</button>
          </form>
        </details>
      ) : null}
      {isAuthor || canModerate ? (
        <form action={deleteContentPostAction} className="danger-action">
          <HiddenContext postId={post.id} slug={slug} />
          <button className="button-danger" type="submit">{isAuthor ? "Hapus post" : "Moderasi post"}</button>
        </form>
      ) : null}

      <section className="reply-section">
        <h3>{post.replies.length} balasan</h3>
        {post.replies.map((reply) => (
          <ReplyCard
            canModerate={canModerate}
            key={reply.id}
            post={post}
            reply={reply}
            slug={slug}
            viewerId={viewerId}
          />
        ))}
        <form action={createContentReplyAction} className="auth-form compact-content-form reply-form">
          <HiddenContext postId={post.id} slug={slug} />
          <input name="parentReplyId" type="hidden" value="" />
          <label htmlFor={`reply-${post.id}`}>Tambahkan balasan</label>
          <textarea id={`reply-${post.id}`} maxLength={5000} name="body" required rows={3} />
          <label htmlFor={`reply-mentions-${post.id}`}>Mention anggota</label>
          <input id={`reply-mentions-${post.id}`} name="mentions" placeholder="@handle, @handle" />
          <button type="submit">Balas</button>
        </form>
      </section>
    </article>
  );
}

export function ContentFeed({
  posts,
  slug,
  viewerId,
  canModerate,
  canInteract,
}: {
  posts: ReadonlyArray<ContentPost>;
  slug: string;
  viewerId: string;
  canModerate: boolean;
  canInteract: boolean;
}) {
  if (!posts.length) {
    return <section className="empty-state content-empty"><p className="eyebrow">Belum ada post</p><h2>Mulai obrolan pertama yang punya konteks.</h2></section>;
  }
  return (
    <section className={`content-feed${canInteract ? "" : " read-only"}`} aria-label="Konten ruang">
      {posts.map((post) => (
        <PostCard canModerate={canModerate} key={post.id} post={post} slug={slug} viewerId={viewerId} />
      ))}
    </section>
  );
}
