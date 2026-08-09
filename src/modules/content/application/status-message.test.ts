import { describe, expect, it } from "vitest";

import { getContentStatusMessage } from "./status-message";

describe("getContentStatusMessage", () => {
  it("returns localized known and fallback messages", () => {
    expect(getContentStatusMessage("post_created")).toContain("diterbitkan");
    expect(getContentStatusMessage("unknown")).toContain("tidak dikenali");
    expect(getContentStatusMessage()).toBeNull();
  });
});
