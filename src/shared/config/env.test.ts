import { describe, expect, it } from "vitest";

import { parsePublicEnv, parseServerEnv } from "./env";

describe("parsePublicEnv", () => {
  it("accepts the public Supabase contract", () => {
    expect(
      parsePublicEnv({
        NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_a-safe-public-key",
        NEXT_PUBLIC_SITE_URL: "https://beta.lingkar.social",
      }),
    ).toMatchObject({ NEXT_PUBLIC_SITE_URL: "https://beta.lingkar.social" });
  });

  it("rejects insecure Supabase origins", () => {
    expect(() =>
      parsePublicEnv({
        NEXT_PUBLIC_SUPABASE_URL: "http://example.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_a-safe-public-key",
      }),
    ).toThrow();
  });
});

describe("parseServerEnv", () => {
  it("accepts a server-only Supabase secret without projecting it publicly", () => {
    const parsed = parseServerEnv({
      NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_a-safe-public-key",
      NEXT_PUBLIC_SITE_URL: "https://beta.lingkar.social",
      SUPABASE_SECRET_KEY: `sb_secret_${"x".repeat(40)}`,
    });

    expect(parsed.SUPABASE_SECRET_KEY).toHaveLength(50);
    expect(Object.keys(parsed).filter((key) => key.startsWith("NEXT_PUBLIC"))).not.toContain(
      "SUPABASE_SECRET_KEY",
    );
  });

  it("rejects a missing trusted mutation key", () => {
    expect(() =>
      parseServerEnv({
        NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_a-safe-public-key",
      }),
    ).toThrow();
  });
});
