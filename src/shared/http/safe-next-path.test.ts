import { describe, expect, it } from "vitest";

import { safeNextPath } from "./safe-next-path";

describe("safeNextPath", () => {
  it("keeps an internal route with query parameters", () => {
    expect(safeNextPath("/auth/update-password?from=invite", "/account")).toBe(
      "/auth/update-password?from=invite",
    );
  });

  it.each([
    "https://evil.example/steal",
    "//evil.example/steal",
    "/\\evil.example/steal",
    "account",
  ])("rejects unsafe redirect target %s", (target) => {
    expect(safeNextPath(target, "/account")).toBe("/account");
  });
});
