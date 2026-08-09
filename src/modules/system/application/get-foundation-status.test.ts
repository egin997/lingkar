import { describe, expect, it } from "vitest";

import { getFoundationStatus } from "./get-foundation-status";

describe("getFoundationStatus", () => {
  it("keeps every Phase 0 gate explicit and uniquely addressable", () => {
    const result = getFoundationStatus();
    const ids = result.gates.map((gate) => gate.id);

    expect(result.phase).toBe("Phase 0 · Verified");
    expect(result.gates).toHaveLength(4);
    expect(new Set(ids).size).toBe(ids.length);
    expect(result.gates.every((gate) => gate.evidence.length > 0)).toBe(true);
  });
});
