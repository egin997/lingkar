import { describe, expect, it } from "vitest";

import {
  createSpaceSchema,
  inviteMemberSchema,
  reputationChangeSchema,
  spaceIdSchema,
} from "./space";

describe("spaces domain validation", () => {
  it("normalizes a valid Indonesian community space", () => {
    expect(
      createSpaceSchema.parse({
        slug: "  Ngoprek-Bareng  ",
        name: "Ngoprek Bareng",
        description: "Belajar dengan konteks.",
        joinPolicy: "request",
        discoverability: "public",
      }),
    ).toMatchObject({ slug: "ngoprek-bareng", joinPolicy: "request" });
  });

  it("rejects unsafe slugs and zero reputation mutations", () => {
    expect(() =>
      createSpaceSchema.parse({
        slug: "../admin",
        name: "Admin palsu",
        description: "",
        joinPolicy: "open",
        discoverability: "public",
      }),
    ).toThrow();
    expect(() =>
      reputationChangeSchema.parse({
        spaceId: "1",
        userId: "11111111-1111-4111-8111-111111111111",
        delta: "0",
        reason: "Tidak berubah",
      }),
    ).toThrow();
  });

  it("rejects unsafe numeric identifiers", () => {
    expect(() => spaceIdSchema.parse(Number.MAX_SAFE_INTEGER + 1)).toThrow();
  });

  it("normalizes an invitation handle and rejects punctuation", () => {
    expect(inviteMemberSchema.parse({ spaceId: "9", handle: "  Teman_Baru  " })).toEqual({
      spaceId: 9,
      handle: "teman_baru",
    });
    expect(inviteMemberSchema.safeParse({ spaceId: 9, handle: "nama.pengguna" }).success).toBe(false);
  });
});
