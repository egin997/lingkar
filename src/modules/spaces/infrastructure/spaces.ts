import "server-only";

import { createServerSupabaseClient } from "@/shared/supabase/server";
import { createTrustedSupabaseClient } from "@/shared/supabase/admin";

export interface SpaceSummary {
  readonly id: number;
  readonly slug: string;
  readonly name: string;
  readonly description: string;
  readonly joinPolicy: "open" | "request" | "invite";
  readonly discoverability: "public" | "unlisted" | "private";
  readonly lifecycle: "active" | "archived";
  readonly ownerId: string;
}

export interface SpaceMember {
  readonly userId: string;
  readonly handle: string;
  readonly displayName: string;
  readonly role: "owner" | "moderator" | "member";
  readonly reputation: number;
}

export interface SpaceDetail {
  readonly space: SpaceSummary;
  readonly members: ReadonlyArray<SpaceMember>;
  readonly rules: ReadonlyArray<{
    readonly id: number;
    readonly position: number;
    readonly title: string;
    readonly body: string;
    readonly isRequired: boolean;
  }>;
  readonly viewerMembership: SpaceMember | null;
  readonly pendingRequests: ReadonlyArray<{
    readonly id: number;
    readonly userId: string;
    readonly handle: string;
    readonly displayName: string;
  }>;
  readonly pendingInvitations: ReadonlyArray<{
    readonly id: number;
    readonly userId: string;
    readonly handle: string;
    readonly displayName: string;
    readonly expiresAt: string;
  }>;
  readonly activeBans: ReadonlyArray<{
    readonly userId: string;
    readonly handle: string;
    readonly displayName: string;
    readonly reason: string;
  }>;
}

function mapSpace(row: Record<string, unknown>): SpaceSummary {
  return {
    id: Number(row.id),
    slug: String(row.slug),
    name: String(row.name),
    description: String(row.description),
    joinPolicy: row.join_policy as SpaceSummary["joinPolicy"],
    discoverability: row.discoverability as SpaceSummary["discoverability"],
    lifecycle: row.lifecycle as SpaceSummary["lifecycle"],
    ownerId: String(row.owner_id),
  };
}

export async function listVisibleSpaces(): Promise<ReadonlyArray<SpaceSummary>> {
  const supabase = await createServerSupabaseClient();
  const { data, error } = await supabase
    .from("spaces")
    .select("id, slug, name, description, join_policy, discoverability, lifecycle, owner_id")
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []).map((row) => mapSpace(row));
}

export async function getSpaceDetail(
  slug: string,
  viewerId: string,
): Promise<SpaceDetail | null> {
  const supabase = await createServerSupabaseClient();
  const spaceResult = await supabase
    .from("spaces")
    .select("id, slug, name, description, join_policy, discoverability, lifecycle, owner_id")
    .eq("slug", slug)
    .maybeSingle();

  if (spaceResult.error) throw spaceResult.error;
  if (!spaceResult.data) return null;
  const space = mapSpace(spaceResult.data);
  const now = new Date().toISOString();

  const [membershipResult, rulesResult, requestResult, invitationResult, banResult] = await Promise.all([
    supabase
      .from("space_memberships")
      .select("user_id, role")
      .eq("space_id", space.id)
      .eq("status", "active")
      .order("joined_at", { ascending: true }),
    supabase
      .from("space_rules")
      .select("id, position, title, body, is_required")
      .eq("space_id", space.id)
      .order("position", { ascending: true }),
    supabase
      .from("space_join_requests")
      .select("id, user_id")
      .eq("space_id", space.id)
      .eq("status", "pending")
      .order("created_at", { ascending: true }),
    supabase
      .from("space_invitations")
      .select("id, user_id, expires_at")
      .eq("space_id", space.id)
      .eq("status", "pending")
      .gt("expires_at", now)
      .order("created_at", { ascending: true }),
    supabase
      .from("space_bans")
      .select("user_id, reason")
      .eq("space_id", space.id)
      .is("revoked_at", null)
      .or(`expires_at.is.null,expires_at.gt.${now}`)
      .order("created_at", { ascending: false }),
  ]);
  if (membershipResult.error) throw membershipResult.error;
  if (rulesResult.error) throw rulesResult.error;
  if (requestResult.error) throw requestResult.error;
  if (invitationResult.error) throw invitationResult.error;
  if (banResult.error) throw banResult.error;

  const membershipRows = membershipResult.data ?? [];
  const requestRows = requestResult.data ?? [];
  const invitationRows = invitationResult.data ?? [];
  const banRows = banResult.data ?? [];
  const userIds = Array.from(
    new Set([
      ...membershipRows.map((row) => String(row.user_id)),
      ...requestRows.map((row) => String(row.user_id)),
      ...invitationRows.map((row) => String(row.user_id)),
      ...banRows.map((row) => String(row.user_id)),
    ]),
  );
  const [profileResult, balanceResult] = await Promise.all([
    userIds.length
      ? supabase.from("profiles").select("user_id, handle, display_name").in("user_id", userIds)
      : Promise.resolve({ data: [], error: null }),
    supabase
      .from("space_reputation_balances")
      .select("user_id, score")
      .eq("space_id", space.id),
  ]);
  if (profileResult.error) throw profileResult.error;
  if (balanceResult.error) throw balanceResult.error;

  const profiles = new Map(
    (profileResult.data ?? []).map((profile) => [
      String(profile.user_id),
      { handle: String(profile.handle), displayName: String(profile.display_name) },
    ]),
  );
  const balances = new Map(
    (balanceResult.data ?? []).map((balance) => [String(balance.user_id), Number(balance.score)]),
  );
  const members = membershipRows.map((membership): SpaceMember => {
    const userId = String(membership.user_id);
    const profile = profiles.get(userId);
    return {
      userId,
      handle: profile?.handle ?? "unknown",
      displayName: profile?.displayName ?? "Pengguna LINGKAR",
      role: membership.role as SpaceMember["role"],
      reputation: balances.get(userId) ?? 0,
    };
  });

  return {
    space,
    members,
    rules: (rulesResult.data ?? []).map((rule) => ({
      id: Number(rule.id),
      position: Number(rule.position),
      title: String(rule.title),
      body: String(rule.body),
      isRequired: Boolean(rule.is_required),
    })),
    viewerMembership: members.find((member) => member.userId === viewerId) ?? null,
    pendingRequests: requestRows.map((request) => {
      const userId = String(request.user_id);
      const profile = profiles.get(userId);
      return {
        id: Number(request.id),
        userId,
        handle: profile?.handle ?? "unknown",
        displayName: profile?.displayName ?? "Pengguna LINGKAR",
      };
    }),
    pendingInvitations: invitationRows.map((invitation) => {
      const userId = String(invitation.user_id);
      const profile = profiles.get(userId);
      return {
        id: Number(invitation.id),
        userId,
        handle: profile?.handle ?? "unknown",
        displayName: profile?.displayName ?? "Pengguna LINGKAR",
        expiresAt: String(invitation.expires_at),
      };
    }),
    activeBans: banRows.map((ban) => {
      const userId = String(ban.user_id);
      const profile = profiles.get(userId);
      return {
        userId,
        handle: profile?.handle ?? "unknown",
        displayName: profile?.displayName ?? "Pengguna LINGKAR",
        reason: String(ban.reason),
      };
    }),
  };
}

export async function findProfileIdByHandle(handle: string): Promise<string | null> {
  const supabase = createTrustedSupabaseClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("user_id")
    .eq("handle", handle)
    .maybeSingle();
  if (error) throw error;
  return data ? String(data.user_id) : null;
}

export async function runTrustedSpaceMutation(
  functionName: string,
  parameters: Record<string, unknown>,
) {
  const supabase = createTrustedSupabaseClient();
  const { data, error } = await supabase.rpc(functionName, parameters);
  return { data, error };
}
