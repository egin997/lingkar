import { describe, expect, it } from "vitest";

import { parsePublicEnv } from "./env";

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
