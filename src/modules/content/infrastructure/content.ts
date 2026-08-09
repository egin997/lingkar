import "server-only";

import { createTrustedSupabaseClient } from "@/shared/supabase/admin";
import { createServerSupabaseClient } from "@/shared/supabase/server";

export interface ContentReply {
  readonly id: number;
  readonly postId: number;
  readonly parentReplyId: number | null;
  readonly authorId: string;
  readonly handle: string;
  readonly displayName: string;
  readonly body: string;
  readonly editedAt: string | null;
  readonly createdAt: string;
  readonly reactions: Readonly<Record<string, number>>;
  readonly viewerReaction: string | null;
}

export interface ContentPost {
  readonly id: number;
  readonly authorId: string;
  readonly handle: string;
  readonly displayName: string;
  readonly kind: "text" | "image" | "link" | "poll" | "question";
  readonly visibility: "space" | "members";
  readonly body: string;
  readonly linkUrl: string | null;
  readonly editedAt: string | null;
  readonly createdAt: string;
  readonly media: ReadonlyArray<{
    readonly id: string;
    readonly filename: string;
    readonly mimeType: string;
    readonly signedUrl: string | null;
  }>;
  readonly poll: null | {
    readonly allowsMultiple: boolean;
    readonly endsAt: string | null;
    readonly options: ReadonlyArray<{
      readonly id: number;
      readonly label: string;
      readonly voteCount: number;
      readonly selectedByViewer: boolean;
    }>;
  };
  readonly acceptedReplyId: number | null;
  readonly replies: ReadonlyArray<ContentReply>;
  readonly reactions: Readonly<Record<string, number>>;
  readonly viewerReaction: string | null;
  readonly viewerSaved: boolean;
  readonly revisionCount: number;
}

function reactionCounts(
  rows: ReadonlyArray<{ reaction: unknown }>,
): Readonly<Record<string, number>> {
  return rows.reduce<Record<string, number>>((counts, row) => {
    const reaction = String(row.reaction);
    counts[reaction] = (counts[reaction] ?? 0) + 1;
    return counts;
  }, {});
}

export async function getSpaceContentFeed(
  spaceId: number,
  viewerId: string,
): Promise<ReadonlyArray<ContentPost>> {
  const supabase = await createServerSupabaseClient();
  const postsResult = await supabase
    .from("content_posts")
    .select("id, author_id, kind, visibility, body, link_url, edited_at, created_at")
    .eq("space_id", spaceId)
    .eq("status", "published")
    .order("created_at", { ascending: false })
    .order("id", { ascending: false });
  if (postsResult.error) throw postsResult.error;
  const postRows = postsResult.data ?? [];
  if (!postRows.length) return [];
  const postIds = postRows.map((post) => Number(post.id));

  const [repliesResult, mediaResult, pollResult, optionResult, questionResult,
    saveResult, profileSeedResult, revisionResult, voteResult] = await Promise.all([
    supabase
      .from("content_replies")
      .select("id, post_id, parent_reply_id, author_id, body, edited_at, created_at")
      .in("post_id", postIds)
      .eq("status", "published")
      .order("created_at", { ascending: true }),
    supabase
      .from("content_media_assets")
      .select("id, post_id, object_path, original_filename, mime_type, position")
      .in("post_id", postIds)
      .eq("status", "attached")
      .order("position", { ascending: true }),
    supabase.from("content_polls").select("post_id, allows_multiple, ends_at").in("post_id", postIds),
    supabase
      .from("content_poll_options")
      .select("id, post_id, label, vote_count, position")
      .in("post_id", postIds)
      .order("position", { ascending: true }),
    supabase.from("content_questions").select("post_id, accepted_reply_id").in("post_id", postIds),
    supabase.from("content_saves").select("post_id").eq("user_id", viewerId).in("post_id", postIds),
    supabase.from("profiles").select("user_id, handle, display_name").in(
      "user_id",
      Array.from(new Set(postRows.map((post) => String(post.author_id)))),
    ),
    supabase.from("content_post_revisions").select("post_id").in("post_id", postIds),
    supabase.from("content_poll_votes").select("post_id, option_id").eq("voter_id", viewerId).in("post_id", postIds),
  ]);
  const results = [repliesResult, mediaResult, pollResult, optionResult, questionResult,
    saveResult, profileSeedResult, revisionResult, voteResult];
  const failed = results.find((result) => result.error);
  if (failed?.error) throw failed.error;

  const replyRows = repliesResult.data ?? [];
  const replyIds = replyRows.map((reply) => Number(reply.id));
  const reactionFilter = [
    `post_id.in.(${postIds.join(",")})`,
    replyIds.length ? `reply_id.in.(${replyIds.join(",")})` : null,
  ].filter((filter): filter is string => Boolean(filter)).join(",");
  const reactionResult = await supabase
    .from("content_reactions")
    .select("actor_id, post_id, reply_id, reaction")
    .or(reactionFilter);
  if (reactionResult.error) throw reactionResult.error;
  const missingAuthorIds = Array.from(
    new Set(replyRows.map((reply) => String(reply.author_id))),
  ).filter((id) => !(profileSeedResult.data ?? []).some((profile) => String(profile.user_id) === id));
  const missingProfilesResult = missingAuthorIds.length
    ? await supabase.from("profiles").select("user_id, handle, display_name").in("user_id", missingAuthorIds)
    : { data: [], error: null };
  if (missingProfilesResult.error) throw missingProfilesResult.error;
  const profiles = new Map(
    [...(profileSeedResult.data ?? []), ...(missingProfilesResult.data ?? [])].map((profile) => [
      String(profile.user_id),
      { handle: String(profile.handle), displayName: String(profile.display_name) },
    ]),
  );

  const mediaRows = mediaResult.data ?? [];
  const mediaPaths = mediaRows.map((media) => String(media.object_path));
  const signedUrls = new Map<string, string | null>();
  if (mediaPaths.length) {
    const signedResult = await supabase.storage.from("content-media").createSignedUrls(mediaPaths, 900);
    if (signedResult.error) throw signedResult.error;
    for (const signed of signedResult.data ?? []) {
      signedUrls.set(String(signed.path), signed.signedUrl ?? null);
    }
  }

  const reactions = reactionResult.data ?? [];
  const savedPostIds = new Set((saveResult.data ?? []).map((saved) => Number(saved.post_id)));
  const selectedOptions = new Set((voteResult.data ?? []).map((vote) => Number(vote.option_id)));
  const revisionCounts = new Map<number, number>();
  for (const revision of revisionResult.data ?? []) {
    const postId = Number(revision.post_id);
    revisionCounts.set(postId, (revisionCounts.get(postId) ?? 0) + 1);
  }

  const mappedReplies = replyRows.map((reply): ContentReply => {
    const id = Number(reply.id);
    const authorId = String(reply.author_id);
    const profile = profiles.get(authorId);
    const replyReactions = reactions.filter((reaction) => Number(reaction.reply_id) === id);
    return {
      id,
      postId: Number(reply.post_id),
      parentReplyId: reply.parent_reply_id ? Number(reply.parent_reply_id) : null,
      authorId,
      handle: profile?.handle ?? "unknown",
      displayName: profile?.displayName ?? "Pengguna LINGKAR",
      body: String(reply.body),
      editedAt: reply.edited_at ? String(reply.edited_at) : null,
      createdAt: String(reply.created_at),
      reactions: reactionCounts(replyReactions),
      viewerReaction: replyReactions.find((reaction) => String(reaction.actor_id) === viewerId)?.reaction
        ? String(replyReactions.find((reaction) => String(reaction.actor_id) === viewerId)?.reaction)
        : null,
    };
  });

  return postRows.map((post): ContentPost => {
    const id = Number(post.id);
    const authorId = String(post.author_id);
    const profile = profiles.get(authorId);
    const postReactions = reactions.filter((reaction) => Number(reaction.post_id) === id);
    const poll = (pollResult.data ?? []).find((candidate) => Number(candidate.post_id) === id);
    const question = (questionResult.data ?? []).find((candidate) => Number(candidate.post_id) === id);
    return {
      id,
      authorId,
      handle: profile?.handle ?? "unknown",
      displayName: profile?.displayName ?? "Pengguna LINGKAR",
      kind: post.kind as ContentPost["kind"],
      visibility: post.visibility as ContentPost["visibility"],
      body: String(post.body),
      linkUrl: post.link_url ? String(post.link_url) : null,
      editedAt: post.edited_at ? String(post.edited_at) : null,
      createdAt: String(post.created_at),
      media: mediaRows
        .filter((media) => Number(media.post_id) === id)
        .map((media) => ({
          id: String(media.id),
          filename: String(media.original_filename),
          mimeType: String(media.mime_type),
          signedUrl: signedUrls.get(String(media.object_path)) ?? null,
        })),
      poll: poll
        ? {
            allowsMultiple: Boolean(poll.allows_multiple),
            endsAt: poll.ends_at ? String(poll.ends_at) : null,
            options: (optionResult.data ?? [])
              .filter((option) => Number(option.post_id) === id)
              .map((option) => ({
                id: Number(option.id),
                label: String(option.label),
                voteCount: Number(option.vote_count),
                selectedByViewer: selectedOptions.has(Number(option.id)),
              })),
          }
        : null,
      acceptedReplyId: question?.accepted_reply_id ? Number(question.accepted_reply_id) : null,
      replies: mappedReplies.filter((reply) => reply.postId === id),
      reactions: reactionCounts(postReactions),
      viewerReaction: postReactions.find((reaction) => String(reaction.actor_id) === viewerId)?.reaction
        ? String(postReactions.find((reaction) => String(reaction.actor_id) === viewerId)?.reaction)
        : null,
      viewerSaved: savedPostIds.has(id),
      revisionCount: revisionCounts.get(id) ?? 0,
    };
  });
}

export async function findContentProfileIdsByHandles(
  handles: ReadonlyArray<string>,
): Promise<ReadonlyArray<string>> {
  if (!handles.length) return [];
  const supabase = createTrustedSupabaseClient();
  const { data, error } = await supabase.from("profiles").select("user_id, handle").in("handle", handles);
  if (error) throw error;
  const idsByHandle = new Map((data ?? []).map((profile) => [String(profile.handle), String(profile.user_id)]));
  if (idsByHandle.size !== handles.length) throw new Error("content_mention_profile_not_found");
  return handles.map((handle) => idsByHandle.get(handle) as string);
}

export async function runTrustedContentMutation(
  functionName: string,
  parameters: Record<string, unknown>,
) {
  const supabase = createTrustedSupabaseClient();
  const { data, error } = await supabase.rpc(functionName, parameters);
  return { data, error };
}

export async function removeStagedContentMedia(assetId: string, objectPath?: string) {
  const supabase = createTrustedSupabaseClient();
  if (objectPath) await supabase.storage.from("content-media").remove([objectPath]);
  await supabase.from("content_media_assets").delete().eq("id", assetId).eq("status", "staged");
}
