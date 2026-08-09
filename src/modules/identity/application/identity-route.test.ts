import { describe, expect, it } from "vitest";

import { identityRoute } from "./identity-route";

describe("identityRoute", () => {
  it.each([
    [{ authenticated: false, onboardingCompleted: false }, "/auth/sign-in"],
    [{ authenticated: true, onboardingCompleted: false }, "/onboarding"],
    [{ authenticated: true, onboardingCompleted: true }, "/account"],
  ] as const)("routes %o to %s", (progress, route) => {
    expect(identityRoute(progress)).toBe(route);
  });
});
