import { z } from "zod";

export const spaceJoinPolicySchema = z.enum(["open", "request", "invite"]);
export const spaceDiscoverabilitySchema = z.enum(["public", "unlisted", "private"]);

export const createSpaceSchema = z.object({
  slug: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z][a-z0-9-]{2,47}$/),
  name: z.string().trim().min(3).max(80),
  description: z.string().trim().max(1000),
  joinPolicy: spaceJoinPolicySchema,
  discoverability: spaceDiscoverabilitySchema,
});

export const spaceIdSchema = z.coerce.number().int().positive().safe();

export const reviewJoinRequestSchema = z.object({
  requestId: spaceIdSchema,
  decision: z.enum(["approved", "rejected"]),
});

export const memberRoleSchema = z.object({
  spaceId: spaceIdSchema,
  userId: z.uuid(),
  role: z.enum(["moderator", "member"]),
});

export const banMemberSchema = z.object({
  spaceId: spaceIdSchema,
  userId: z.uuid(),
  reason: z.string().trim().min(3).max(500),
});

export const inviteMemberSchema = z.object({
  spaceId: spaceIdSchema,
  handle: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z0-9_]{3,24}$/),
});

export const reputationChangeSchema = z.object({
  spaceId: spaceIdSchema,
  userId: z.uuid(),
  delta: z.coerce.number().int().min(-100).max(100).refine((value) => value !== 0),
  reason: z.string().trim().min(3).max(200),
});

export const spaceRuleSchema = z.object({
  spaceId: spaceIdSchema,
  ruleId: z.union([spaceIdSchema, z.null()]),
  position: z.coerce.number().int().min(1).max(50),
  title: z.string().trim().min(3).max(100),
  body: z.string().trim().min(3).max(1000),
  isRequired: z.boolean(),
});

export type CreateSpaceInput = z.infer<typeof createSpaceSchema>;
