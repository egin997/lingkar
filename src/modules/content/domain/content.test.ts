import { describe, expect, it } from "vitest";

import {
  createContentPostSchema,
  parseMentionHandles,
  safeMediaFilename,
  setContentSavedSchema,
} from "./content";

describe("content domain", () => {
  const base = {
    spaceId: "10",
    slug: "ruang-uji",
    visibility: "space",
    body: "Isi yang relevan",
    requestKey: "30000000-0000-4000-8000-000000000001",
  };

  it("validates text and HTTPS link posts", () => {
    expect(createContentPostSchema.safeParse({ ...base, kind: "text" }).success).toBe(true);
    expect(
      createContentPostSchema.safeParse({
        ...base,
        kind: "link",
        linkUrl: "https://example.com/referensi",
      }).success,
    ).toBe(true);
    expect(
      createContentPostSchema.safeParse({
        ...base,
        kind: "link",
        linkUrl: "http://example.com/tidak-aman",
      }).success,
    ).toBe(false);
  });

  it("requires poll options only for polls", () => {
    expect(
      createContentPostSchema.safeParse({
        ...base,
        kind: "poll",
        pollOptions: ["Satu", "Dua"],
      }).success,
    ).toBe(true);
    expect(
      createContentPostSchema.safeParse({ ...base, kind: "poll", pollOptions: ["Satu"] }).success,
    ).toBe(false);
    expect(
      createContentPostSchema.safeParse({ ...base, kind: "text", pollOptions: ["Satu", "Dua"] })
        .success,
    ).toBe(false);
  });

  it("normalizes and deduplicates mention handles", () => {
    expect(parseMentionHandles(" @Yun,ara, yun ")).toEqual(["yun", "ara"]);
    expect(() => parseMentionHandles("bad handle")).toThrow();
  });

  it("sanitizes media filenames and parses explicit save state", () => {
    expect(safeMediaFilename("foto liburan (1).webp")).toBe("foto-liburan-1-.webp");
    expect(
      setContentSavedSchema.parse({
        postId: "4",
        slug: "ruang-uji",
        saved: "false",
        requestKey: "30000000-0000-4000-8000-000000000002",
      }).saved,
    ).toBe(false);
  });
});
