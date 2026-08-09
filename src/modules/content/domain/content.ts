import { z } from "zod";

export const contentIdSchema = z.coerce.number().int().positive().safe();
export const contentRequestKeySchema = z.uuid();
export const contentKindSchema = z.enum(["text", "image", "link", "poll", "question"]);
export const contentVisibilitySchema = z.enum(["space", "members"]);
export const contentReactionSchema = z.enum(["apresiasi", "membantu", "menarik"]);

const handleSchema = z.string().trim().toLowerCase().regex(/^[a-z0-9_]{3,24}$/);

export function parseMentionHandles(value: FormDataEntryValue | null): ReadonlyArray<string> {
  if (typeof value !== "string" || !value.trim()) return [];
  const handles = value
    .split(",")
    .map((handle) => handle.trim().replace(/^@/, "").toLowerCase())
    .filter(Boolean);
  return z.array(handleSchema).max(20).parse(Array.from(new Set(handles)));
}

export const createContentPostSchema = z
  .object({
    spaceId: contentIdSchema,
    slug: z.string().trim().min(3).max(48),
    kind: z.enum(["text", "link", "poll", "question"]),
    visibility: contentVisibilitySchema,
    body: z.string().trim().max(10_000),
    linkUrl: z.string().trim().max(2_048).optional().default(""),
    pollOptions: z.array(z.string().trim().min(1).max(120)).max(10).default([]),
    pollAllowsMultiple: z.boolean().default(false),
    requestKey: contentRequestKeySchema,
  })
  .superRefine((value, context) => {
    if (!value.body) {
      context.addIssue({ code: "custom", path: ["body"], message: "body_required" });
    }
    if (value.kind === "link") {
      const parsed = z.url().safeParse(value.linkUrl);
      if (!parsed.success || !value.linkUrl.startsWith("https://")) {
        context.addIssue({ code: "custom", path: ["linkUrl"], message: "https_link_required" });
      }
    } else if (value.linkUrl) {
      context.addIssue({ code: "custom", path: ["linkUrl"], message: "unexpected_link" });
    }
    if (value.kind === "poll" && (value.pollOptions.length < 2 || value.pollOptions.length > 10)) {
      context.addIssue({ code: "custom", path: ["pollOptions"], message: "poll_options_required" });
    }
    if (value.kind !== "poll" && value.pollOptions.length) {
      context.addIssue({ code: "custom", path: ["pollOptions"], message: "unexpected_poll" });
    }
  });

export const editContentPostSchema = z.object({
  postId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  visibility: contentVisibilitySchema,
  body: z.string().trim().max(10_000),
  linkUrl: z.string().trim().max(2_048).optional().default(""),
  requestKey: contentRequestKeySchema,
});

export const contentReplySchema = z.object({
  postId: contentIdSchema,
  parentReplyId: z.union([contentIdSchema, z.null()]),
  slug: z.string().trim().min(3).max(48),
  body: z.string().trim().min(1).max(5_000),
  requestKey: contentRequestKeySchema,
});

export const editContentReplySchema = z.object({
  replyId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  body: z.string().trim().min(1).max(5_000),
  requestKey: contentRequestKeySchema,
});

export const contentTargetSchema = z.object({
  targetType: z.enum(["post", "reply"]),
  targetId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  requestKey: contentRequestKeySchema,
});

export const setContentReactionSchema = contentTargetSchema.extend({
  reaction: z.union([contentReactionSchema, z.literal("removed")]),
});

export const setContentSavedSchema = z.object({
  postId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  saved: z.enum(["true", "false"]).transform((value) => value === "true"),
  requestKey: contentRequestKeySchema,
});

export const voteContentPollSchema = z.object({
  postId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  optionIds: z.array(contentIdSchema).min(1).max(10),
  requestKey: contentRequestKeySchema,
});

export const acceptContentAnswerSchema = z.object({
  postId: contentIdSchema,
  replyId: z.union([contentIdSchema, z.null()]),
  slug: z.string().trim().min(3).max(48),
  requestKey: contentRequestKeySchema,
});

export const deleteContentSchema = z.object({
  targetId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  requestKey: contentRequestKeySchema,
});

export const imageUploadSchema = z.object({
  spaceId: contentIdSchema,
  slug: z.string().trim().min(3).max(48),
  visibility: contentVisibilitySchema,
  body: z.string().trim().max(10_000),
  requestKey: contentRequestKeySchema,
});

export function safeMediaFilename(filename: string): string {
  const normalized = filename
    .normalize("NFKD")
    .replace(/[^A-Za-z0-9._-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 120);
  return /^[A-Za-z0-9]/.test(normalized) ? normalized : `image-${Date.now()}`;
}
