import { describe, expect, it } from "vitest";

import { spaceStatusMessage } from "./status-message";

describe("spaceStatusMessage", () => {
  it("maps known mutation outcomes and ignores unknown values", () => {
    expect(spaceStatusMessage("requested")).toContain("antrean moderator");
    expect(spaceStatusMessage("unknown")).toBeNull();
    expect(spaceStatusMessage(undefined)).toBeNull();
  });
});
