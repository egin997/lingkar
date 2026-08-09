import { describe, expect, it } from "vitest";

import {
  AGE_ATTESTATION_VERSION,
  onboardingRpcInput,
  onboardingSchema,
  passwordUpdateSchema,
  profileUpdateSchema,
  signInSchema,
  TERMS_VERSION,
} from "./identity";

describe("identity input contracts", () => {
  it("normalizes email and handles before infrastructure calls", () => {
    expect(signInSchema.parse({ email: "  USER@Example.COM ", password: "secret" })).toEqual({
      email: "user@example.com",
      password: "secret",
    });

    const onboarding = onboardingSchema.parse({
      handle: "  Lingkar_User ",
      displayName: "  Nama Pengguna  ",
      adultAttestation: "on",
      termsAcceptance: "on",
    });

    expect(onboardingRpcInput(onboarding)).toEqual({
      requested_handle: "lingkar_user",
      requested_display_name: "Nama Pengguna",
      accepted_age_version: AGE_ATTESTATION_VERSION,
      accepted_terms_version: TERMS_VERSION,
    });
  });

  it.each(["ab", "1mulaiangka", "huruf-tengah"])(
    "rejects non-canonical handle %s",
    (handle) => {
      expect(
        onboardingSchema.safeParse({
          handle,
          displayName: "Nama Pengguna",
          adultAttestation: "on",
          termsAcceptance: "on",
        }).success,
      ).toBe(false);
    },
  );

  it("requires explicit 18+ and terms attestations", () => {
    expect(
      onboardingSchema.safeParse({
        handle: "pengguna",
        displayName: "Nama Pengguna",
      }).success,
    ).toBe(false);
  });

  it("enforces strong matching passwords", () => {
    expect(
      passwordUpdateSchema.safeParse({
        password: "StrongPass1!",
        passwordConfirmation: "StrongPass1!",
      }).success,
    ).toBe(true);
    expect(
      passwordUpdateSchema.safeParse({
        password: "weakpassword",
        passwordConfirmation: "different",
      }).success,
    ).toBe(false);
  });

  it("limits public profile fields", () => {
    expect(
      profileUpdateSchema.safeParse({
        handle: "pengguna",
        displayName: "Nama Pengguna",
        bio: "x".repeat(281),
      }).success,
    ).toBe(false);
  });
});
