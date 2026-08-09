"use server";

import { redirect } from "next/navigation";

import {
  acceptContentAnswerSchema,
  contentReplySchema,
  deleteContentSchema,
  editContentPostSchema,
  editContentReplySchema,
  parseMentionHandles,
  setContentReactionSchema,
  setContentSavedSchema,
  voteContentPollSchema,
  createContentPostSchema,
} from "@/modules/content/domain/content";
import {
  findContentProfileIdsByHandles,
  runTrustedContentMutation,
} from "@/modules/content/infrastructure/content";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";

function contentLocation(slug: string, status: string, postId?: number) {
  const anchor = postId ? `#post-${postId}` : "#content";
  return `/spaces/${encodeURIComponent(slug)}?${new URLSearchParams({ status })}${anchor}`;
}

async function requireActor() {
  const viewer = await getViewerIdentity();
  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (!viewer.onboardingCompleted) redirect("/onboarding");
  return viewer.userId;
}

function mutationFailure(error: { message?: string } | null) {
  return error?.message?.includes("content_rate_limit_exceeded") ? "rate_limited" : "content_failed";
}

async function mentionIds(formData: FormData) {
  const handles = parseMentionHandles(formData.get("mentions"));
  return findContentProfileIdsByHandles(handles);
}

export async function createContentPostAction(formData: FormData) {
  const actorId = await requireActor();
  let mentions: ReadonlyArray<string>;
  try {
    mentions = await mentionIds(formData);
  } catch {
    redirect(contentLocation(String(formData.get("slug") ?? ""), "invalid_content"));
  }
  const pollOptions = formData
    .getAll("pollOption")
    .filter((entry): entry is string => typeof entry === "string")
    .map((entry) => entry.trim())
    .filter(Boolean);
  const parsed = createContentPostSchema.safeParse({
    spaceId: formData.get("spaceId"),
    slug: formData.get("slug"),
    kind: formData.get("kind"),
    visibility: formData.get("visibility"),
    body: formData.get("body"),
    linkUrl: formData.get("linkUrl") ?? "",
    pollOptions,
    pollAllowsMultiple: formData.get("pollAllowsMultiple") === "on",
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect(contentLocation(String(formData.get("slug") ?? ""), "invalid_content"));
  const { data, error } = await runTrustedContentMutation("create_content_post", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    requested_kind: parsed.data.kind,
    requested_visibility: parsed.data.visibility,
    requested_body: parsed.data.body,
    requested_link_url: parsed.data.linkUrl || null,
    requested_poll_options: parsed.data.pollOptions,
    requested_poll_allows_multiple: parsed.data.pollAllowsMultiple,
    requested_poll_ends_at: null,
    requested_media_asset_ids: [],
    mentioned_user_ids: mentions,
    request_key: parsed.data.requestKey,
  });
  if (error) redirect(contentLocation(parsed.data.slug, mutationFailure(error)));
  redirect(contentLocation(parsed.data.slug, "post_created", Number(data)));
}

export async function editContentPostAction(formData: FormData) {
  const actorId = await requireActor();
  let mentions: ReadonlyArray<string>;
  try {
    mentions = await mentionIds(formData);
  } catch {
    redirect(contentLocation(String(formData.get("slug") ?? ""), "invalid_content"));
  }
  const parsed = editContentPostSchema.safeParse({
    postId: formData.get("postId"),
    slug: formData.get("slug"),
    visibility: formData.get("visibility"),
    body: formData.get("body"),
    linkUrl: formData.get("linkUrl") ?? "",
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect(contentLocation(String(formData.get("slug") ?? ""), "invalid_content"));
  const { error } = await runTrustedContentMutation("edit_content_post", {
    acting_user_id: actorId,
    target_post_id: parsed.data.postId,
    requested_visibility: parsed.data.visibility,
    requested_body: parsed.data.body,
    requested_link_url: parsed.data.linkUrl || null,
    mentioned_user_ids: mentions,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "post_edited", parsed.data.postId));
}

export async function deleteContentPostAction(formData: FormData) {
  const parsed = deleteContentSchema.safeParse({
    targetId: formData.get("postId"),
    slug: formData.get("slug"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const actorId = await requireActor();
  const { error } = await runTrustedContentMutation("delete_content_post", {
    acting_user_id: actorId,
    target_post_id: parsed.data.targetId,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "post_deleted"));
}

export async function createContentReplyAction(formData: FormData) {
  const actorId = await requireActor();
  let mentions: ReadonlyArray<string>;
  try {
    mentions = await mentionIds(formData);
  } catch {
    redirect(contentLocation(String(formData.get("slug") ?? ""), "invalid_content"));
  }
  const parentValue = formData.get("parentReplyId");
  const parsed = contentReplySchema.safeParse({
    postId: formData.get("postId"),
    parentReplyId: parentValue ? parentValue : null,
    slug: formData.get("slug"),
    body: formData.get("body"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const { error } = await runTrustedContentMutation("create_content_reply", {
    acting_user_id: actorId,
    target_post_id: parsed.data.postId,
    target_parent_reply_id: parsed.data.parentReplyId,
    requested_body: parsed.data.body,
    mentioned_user_ids: mentions,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "reply_created", parsed.data.postId));
}

export async function editContentReplyAction(formData: FormData) {
  const actorId = await requireActor();
  let mentions: ReadonlyArray<string>;
  try {
    mentions = await mentionIds(formData);
  } catch {
    redirect(contentLocation(String(formData.get("slug") ?? ""), "invalid_content"));
  }
  const parsed = editContentReplySchema.safeParse({
    replyId: formData.get("replyId"),
    slug: formData.get("slug"),
    body: formData.get("body"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const { error } = await runTrustedContentMutation("edit_content_reply", {
    acting_user_id: actorId,
    target_reply_id: parsed.data.replyId,
    requested_body: parsed.data.body,
    mentioned_user_ids: mentions,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "reply_edited"));
}

export async function deleteContentReplyAction(formData: FormData) {
  const parsed = deleteContentSchema.safeParse({
    targetId: formData.get("replyId"),
    slug: formData.get("slug"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const actorId = await requireActor();
  const { error } = await runTrustedContentMutation("delete_content_reply", {
    acting_user_id: actorId,
    target_reply_id: parsed.data.targetId,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "reply_deleted"));
}

export async function setContentReactionAction(formData: FormData) {
  const parsed = setContentReactionSchema.safeParse({
    targetType: formData.get("targetType"),
    targetId: formData.get("targetId"),
    slug: formData.get("slug"),
    reaction: formData.get("reaction"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const actorId = await requireActor();
  const { error } = await runTrustedContentMutation("set_content_reaction", {
    acting_user_id: actorId,
    target_type: parsed.data.targetType,
    target_id: parsed.data.targetId,
    requested_reaction: parsed.data.reaction === "removed" ? null : parsed.data.reaction,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "reaction_updated"));
}

export async function setContentSavedAction(formData: FormData) {
  const parsed = setContentSavedSchema.safeParse({
    postId: formData.get("postId"),
    slug: formData.get("slug"),
    saved: formData.get("saved"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const actorId = await requireActor();
  const { error } = await runTrustedContentMutation("set_content_saved", {
    acting_user_id: actorId,
    target_post_id: parsed.data.postId,
    should_save: parsed.data.saved,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "save_updated", parsed.data.postId));
}

export async function voteContentPollAction(formData: FormData) {
  const parsed = voteContentPollSchema.safeParse({
    postId: formData.get("postId"),
    slug: formData.get("slug"),
    optionIds: formData.getAll("optionId"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const actorId = await requireActor();
  const { error } = await runTrustedContentMutation("vote_content_poll", {
    acting_user_id: actorId,
    target_post_id: parsed.data.postId,
    selected_option_ids: parsed.data.optionIds,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "vote_recorded", parsed.data.postId));
}

export async function acceptContentAnswerAction(formData: FormData) {
  const replyValue = formData.get("replyId");
  const parsed = acceptContentAnswerSchema.safeParse({
    postId: formData.get("postId"),
    replyId: replyValue ? replyValue : null,
    slug: formData.get("slug"),
    requestKey: formData.get("requestKey"),
  });
  if (!parsed.success) redirect("/spaces?status=invalid_content");
  const actorId = await requireActor();
  const { error } = await runTrustedContentMutation("accept_content_answer", {
    acting_user_id: actorId,
    target_post_id: parsed.data.postId,
    target_reply_id: parsed.data.replyId,
    request_key: parsed.data.requestKey,
  });
  redirect(contentLocation(parsed.data.slug, error ? mutationFailure(error) : "answer_updated", parsed.data.postId));
}
