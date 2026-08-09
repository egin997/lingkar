import { randomUUID } from "node:crypto";

import { NextRequest, NextResponse } from "next/server";

import {
  contentRequestKeySchema,
  imageUploadSchema,
  parseMentionHandles,
  safeMediaFilename,
} from "@/modules/content/domain/content";
import {
  findContentProfileIdsByHandles,
  removeStagedContentMedia,
  runTrustedContentMutation,
} from "@/modules/content/infrastructure/content";
import { getViewerIdentity } from "@/modules/identity/infrastructure/viewer";
import { createServerSupabaseClient } from "@/shared/supabase/server";

const allowedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp", "image/gif"]);

function destination(request: NextRequest, slug: string, status: string) {
  const path = slug ? `/spaces/${encodeURIComponent(slug)}` : "/spaces";
  return new URL(`${path}?${new URLSearchParams({ status })}#content`, request.url);
}

export async function POST(request: NextRequest) {
  const viewer = await getViewerIdentity();
  if (!viewer) return NextResponse.redirect(new URL("/auth/sign-in?status=session_expired", request.url), 303);
  if (!viewer.onboardingCompleted) return NextResponse.redirect(new URL("/onboarding", request.url), 303);

  const formData = await request.formData();
  const slug = String(formData.get("slug") ?? "");
  const parsed = imageUploadSchema.safeParse({
    spaceId: formData.get("spaceId"),
    slug,
    visibility: formData.get("visibility"),
    body: formData.get("body"),
    requestKey: formData.get("requestKey"),
  });
  const assetId = contentRequestKeySchema.safeParse(formData.get("assetId"));
  const registerRequestKey = contentRequestKeySchema.safeParse(formData.get("registerRequestKey"));
  const file = formData.get("image");
  if (
    !parsed.success ||
    !assetId.success ||
    !registerRequestKey.success ||
    !(file instanceof File) ||
    !allowedMimeTypes.has(file.type) ||
    file.size < 1 ||
    file.size > 5 * 1024 * 1024
  ) {
    return NextResponse.redirect(destination(request, slug, "image_failed"), 303);
  }

  let mentionedUserIds: ReadonlyArray<string>;
  try {
    mentionedUserIds = await findContentProfileIdsByHandles(parseMentionHandles(formData.get("mentions")));
  } catch {
    return NextResponse.redirect(destination(request, slug, "invalid_content"), 303);
  }

  const filename = safeMediaFilename(file.name || `image-${randomUUID()}`);
  const registered = await runTrustedContentMutation("register_content_media", {
    acting_user_id: viewer.userId,
    target_space_id: parsed.data.spaceId,
    requested_asset_id: assetId.data,
    requested_filename: filename,
    requested_mime_type: file.type,
    requested_byte_size: file.size,
    request_key: registerRequestKey.data,
  });
  if (registered.error || !registered.data || typeof registered.data !== "object") {
    return NextResponse.redirect(destination(request, slug, "image_failed"), 303);
  }
  const asset = registered.data as { id?: unknown; object_path?: unknown };
  const objectPath = typeof asset.object_path === "string" ? asset.object_path : null;
  if (asset.id !== assetId.data || !objectPath) {
    await removeStagedContentMedia(assetId.data);
    return NextResponse.redirect(destination(request, slug, "image_failed"), 303);
  }

  const supabase = await createServerSupabaseClient();
  const uploaded = await supabase.storage.from("content-media").upload(
    objectPath,
    file,
    { cacheControl: "3600", contentType: file.type, upsert: false },
  );
  if (uploaded.error) {
    await removeStagedContentMedia(assetId.data, objectPath);
    return NextResponse.redirect(destination(request, slug, "image_failed"), 303);
  }

  const created = await runTrustedContentMutation("create_content_post", {
    acting_user_id: viewer.userId,
    target_space_id: parsed.data.spaceId,
    requested_kind: "image",
    requested_visibility: parsed.data.visibility,
    requested_body: parsed.data.body,
    requested_link_url: null,
    requested_poll_options: [],
    requested_poll_allows_multiple: false,
    requested_poll_ends_at: null,
    requested_media_asset_ids: [assetId.data],
    mentioned_user_ids: mentionedUserIds,
    request_key: parsed.data.requestKey,
  });
  if (created.error) {
    await removeStagedContentMedia(assetId.data, objectPath);
    const status = created.error.message.includes("content_rate_limit_exceeded")
      ? "rate_limited"
      : "image_failed";
    return NextResponse.redirect(destination(request, slug, status), 303);
  }
  return NextResponse.redirect(destination(request, slug, "image_created"), 303);
}
