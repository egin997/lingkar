import { describe, expect, it } from "vitest";

import { identityStatusMessage } from "./status-message";

describe("identityStatusMessage", () => {
  it("maps public error codes without reflecting arbitrary input", () => {
    expect(identityStatusMessage("invalid_credentials")).toBe("Email atau password tidak cocok.");
    expect(identityStatusMessage("<script>alert(1)</script>")).toBeNull();
  });
});
