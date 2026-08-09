import { describe, expect, it, vi } from "vitest";

import { main, parseLocalStatus } from "./local-auth-fixtures.mjs";

describe("parseLocalStatus", () => {
  it("accepts loopback Supabase credentials", () => {
    const serviceRoleKey = "x".repeat(40);
    expect(
      parseLocalStatus({ API_URL: "http://127.0.0.1:54321", SERVICE_ROLE_KEY: serviceRoleKey }),
    ).toEqual({ apiUrl: "http://127.0.0.1:54321", serviceRoleKey });
  });

  it.each(["https://example.supabase.co", "http://192.0.2.1:54321"])(
    "rejects non-local target %s",
    (apiUrl) => {
      expect(() =>
        parseLocalStatus({ API_URL: apiUrl, SERVICE_ROLE_KEY: "x".repeat(40) }),
      ).toThrow(/local Supabase/);
    },
  );
});

describe("main", () => {
  it("creates the four deterministic users without logging credentials", async () => {
    const createUser = vi.fn(async ({ id }) => ({ data: { user: { id } }, error: null }));
    const messages = [];

    await main({
      load: async () => ({ apiUrl: "http://127.0.0.1:54321", serviceRoleKey: "x".repeat(40) }),
      log: (message) => messages.push(message),
      clientFactory: () => ({ auth: { admin: { createUser } } }),
    });

    expect(createUser).toHaveBeenCalledTimes(4);
    expect(messages).toEqual(["Created 4 deterministic local Auth audit fixtures."]);
  });
});
