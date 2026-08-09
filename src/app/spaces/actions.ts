"use server";

import { randomUUID } from "node:crypto";
import { redirect } from "next/navigation";

import {
  banMemberSchema,
  createSpaceSchema,
  inviteMemberSchema,
  memberRoleSchema,
  reputationChangeSchema,
  reviewJoinRequestSchema,
  spaceIdSchema,
  spaceRuleSchema,
} from "@/modules/spaces/domain/space";
import {
  findProfileIdByHandle,
  runTrustedSpaceMutation,
} from "@/modules/spaces/infrastructure/spaces";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";

function spaceLocation(slug: string, status: string, manage = false) {
  const suffix = manage ? "/manage" : "";
  return `/spaces/${encodeURIComponent(slug)}${suffix}?${new URLSearchParams({ status })}`;
}

async function requireActor() {
  const viewer = await getViewerIdentity();
  if (!viewer) redirect("/auth/sign-in?status=session_expired");
  if (!viewer.onboardingCompleted) redirect("/onboarding");
  return viewer.userId;
}

export async function createSpaceAction(formData: FormData) {
  const parsed = createSpaceSchema.safeParse({
    slug: formData.get("slug"),
    name: formData.get("name"),
    description: formData.get("description"),
    joinPolicy: formData.get("joinPolicy"),
    discoverability: formData.get("discoverability"),
  });
  if (!parsed.success) redirect("/spaces/new?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("create_space", {
    acting_user_id: actorId,
    requested_slug: parsed.data.slug,
    requested_name: parsed.data.name,
    requested_description: parsed.data.description,
    requested_join_policy: parsed.data.joinPolicy,
    requested_discoverability: parsed.data.discoverability,
  });
  if (error) redirect("/spaces/new?status=create_failed");
  redirect(`/spaces/${encodeURIComponent(parsed.data.slug)}`);
}

export async function joinSpaceAction(formData: FormData) {
  const parsed = spaceIdSchema.safeParse(formData.get("spaceId"));
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { data, error } = await runTrustedSpaceMutation("join_space", {
    acting_user_id: actorId,
    target_space_id: parsed.data,
  });
  if (error) redirect(spaceLocation(slug, "join_failed"));
  redirect(spaceLocation(slug, data === "requested" ? "requested" : "joined"));
}

export async function leaveSpaceAction(formData: FormData) {
  const parsed = spaceIdSchema.safeParse(formData.get("spaceId"));
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("leave_space", {
    acting_user_id: actorId,
    target_space_id: parsed.data,
  });
  if (error) redirect(spaceLocation(slug, "moderation_failed"));
  redirect(spaceLocation(slug, "left"));
}

export async function reviewJoinRequestAction(formData: FormData) {
  const parsed = reviewJoinRequestSchema.safeParse({
    requestId: formData.get("requestId"),
    decision: formData.get("decision"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("review_space_join_request", {
    acting_user_id: actorId,
    target_request_id: parsed.data.requestId,
    decision: parsed.data.decision,
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "request_reviewed", true));
}

export async function inviteMemberAction(formData: FormData) {
  const parsed = inviteMemberSchema.safeParse({
    spaceId: formData.get("spaceId"),
    handle: formData.get("handle"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const targetUserId = await findProfileIdByHandle(parsed.data.handle);
  if (!targetUserId) redirect(spaceLocation(slug, "invite_failed", true));
  const { error } = await runTrustedSpaceMutation("invite_space_member", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_user_id: targetUserId,
    invitation_expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  });
  redirect(spaceLocation(slug, error ? "invite_failed" : "invited", true));
}

export async function setMemberRoleAction(formData: FormData) {
  const parsed = memberRoleSchema.safeParse({
    spaceId: formData.get("spaceId"),
    userId: formData.get("userId"),
    role: formData.get("role"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("set_space_member_role", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_user_id: parsed.data.userId,
    requested_role: parsed.data.role,
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "role_updated", true));
}

export async function transferOwnershipAction(formData: FormData) {
  const parsed = memberRoleSchema.pick({ spaceId: true, userId: true }).safeParse({
    spaceId: formData.get("spaceId"),
    userId: formData.get("userId"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("transfer_space_ownership", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    new_owner_id: parsed.data.userId,
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "ownership_transferred", true));
}

export async function banMemberAction(formData: FormData) {
  const parsed = banMemberSchema.safeParse({
    spaceId: formData.get("spaceId"),
    userId: formData.get("userId"),
    reason: formData.get("reason"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("ban_space_member", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_user_id: parsed.data.userId,
    ban_reason: parsed.data.reason,
    ban_expires_at: null,
  });
  redirect(spaceLocation(slug, error ? "ban_failed" : "banned", true));
}

export async function unbanMemberAction(formData: FormData) {
  const parsed = memberRoleSchema.pick({ spaceId: true, userId: true }).safeParse({
    spaceId: formData.get("spaceId"),
    userId: formData.get("userId"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("unban_space_member", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_user_id: parsed.data.userId,
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "unbanned", true));
}

export async function changeReputationAction(formData: FormData) {
  const parsed = reputationChangeSchema.safeParse({
    spaceId: formData.get("spaceId"),
    userId: formData.get("userId"),
    delta: formData.get("delta"),
    reason: formData.get("reason"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("add_space_reputation", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_user_id: parsed.data.userId,
    score_delta: parsed.data.delta,
    change_reason: parsed.data.reason,
    request_key: randomUUID(),
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "reputation_updated", true));
}

export async function saveSpaceRuleAction(formData: FormData) {
  const ruleIdValue = String(formData.get("ruleId") ?? "").trim();
  const parsed = spaceRuleSchema.safeParse({
    spaceId: formData.get("spaceId"),
    ruleId: ruleIdValue ? ruleIdValue : null,
    position: formData.get("position"),
    title: formData.get("title"),
    body: formData.get("body"),
    isRequired: formData.get("isRequired") === "on",
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("upsert_space_rule", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_rule_id: parsed.data.ruleId,
    requested_position: parsed.data.position,
    requested_title: parsed.data.title,
    requested_body: parsed.data.body,
    requested_is_required: parsed.data.isRequired,
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "rule_saved", true));
}

export async function removeSpaceRuleAction(formData: FormData) {
  const parsed = spaceRuleSchema.pick({ spaceId: true, ruleId: true }).safeParse({
    spaceId: formData.get("spaceId"),
    ruleId: formData.get("ruleId"),
  });
  const slug = String(formData.get("slug") ?? "");
  if (!parsed.success || !parsed.data.ruleId || !slug) redirect("/spaces?status=invalid_input");
  const actorId = await requireActor();
  const { error } = await runTrustedSpaceMutation("remove_space_rule", {
    acting_user_id: actorId,
    target_space_id: parsed.data.spaceId,
    target_rule_id: parsed.data.ruleId,
  });
  redirect(spaceLocation(slug, error ? "moderation_failed" : "rule_removed", true));
}
