import { describe, expect, it } from "vitest";

import { RESET_ACKNOWLEDGEMENT, main, validateTarget } from "./assert-disposable-supabase.mjs";

const safeTarget = {
  linkedRef: "abcdefghijklmnopqrst",
  expectedRef: "abcdefghijklmnopqrst",
  environment: "disposable",
  acknowledgement: RESET_ACKNOWLEDGEMENT,
};

describe("validateTarget", () => {
  it("accepts an exact ref and explicit disposable acknowledgement", () => {
    expect(validateTarget(safeTarget)).toEqual({
      projectRef: safeTarget.linkedRef,
      environment: "disposable",
    });
  });

  it.each(["audit", "dev", "staging", "throwaway"])("accepts the %s environment label", (environment) => {
    expect(validateTarget({ ...safeTarget, environment })).toMatchObject({ environment });
  });

  it("rejects a mismatched linked ref", () => {
    expect(() => validateTarget({ ...safeTarget, expectedRef: "different" })).toThrow(/ref/);
  });

  it.each([undefined, "production", "prod", "important"])("rejects unsafe environment %s", (environment) => {
    expect(() => validateTarget({ ...safeTarget, environment })).toThrow(/environment/);
  });

  it("rejects a missing destructive reset acknowledgement", () => {
    expect(() => validateTarget({ ...safeTarget, acknowledgement: undefined })).toThrow(/acknowledgement/);
  });
});

describe("main", () => {
  it("reads the linked ref, validates the environment, and records non-secret evidence", async () => {
    const messages = [];

    await expect(
      main({
        read: async () => ` ${safeTarget.linkedRef}\n`,
        environmentVariables: {
          SUPABASE_AUDIT_PROJECT_REF: safeTarget.expectedRef,
          SUPABASE_AUDIT_ENVIRONMENT: safeTarget.environment,
          SUPABASE_AUDIT_RESET_ACK: safeTarget.acknowledgement,
        },
        log: (message) => messages.push(message),
      }),
    ).resolves.toEqual({ projectRef: safeTarget.linkedRef, environment: "disposable" });

    expect(messages).toEqual([
      `Verified disposable Supabase target: ${safeTarget.linkedRef} (disposable)`,
    ]);
  });

  it("fails closed when no linked project metadata exists", async () => {
    await expect(
      main({
        read: async () => {
          throw new Error("missing");
        },
      }),
    ).rejects.toThrow(/No linked Supabase project/);
  });
});
