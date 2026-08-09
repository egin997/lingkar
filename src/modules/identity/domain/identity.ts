import { z } from "zod";

export const AGE_ATTESTATION_VERSION = "18plus-v1" as const;
export const TERMS_VERSION = "closed-beta-v1" as const;

const passwordSchema = z
  .string()
  .min(10, "Password minimal 10 karakter.")
  .max(72, "Password maksimal 72 karakter.")
  .regex(/[a-z]/, "Password perlu huruf kecil.")
  .regex(/[A-Z]/, "Password perlu huruf besar.")
  .regex(/[0-9]/, "Password perlu angka.")
  .regex(/[^A-Za-z0-9]/, "Password perlu simbol.");

export const signInSchema = z.object({
  email: z
    .string()
    .trim()
    .pipe(z.email().max(254))
    .transform((value) => value.toLowerCase()),
  password: z.string().min(1).max(72),
});

export const recoverySchema = z.object({
  email: z
    .string()
    .trim()
    .pipe(z.email().max(254))
    .transform((value) => value.toLowerCase()),
});

export const passwordUpdateSchema = z
  .object({
    password: passwordSchema,
    passwordConfirmation: z.string(),
  })
  .refine(({ password, passwordConfirmation }) => password === passwordConfirmation, {
    message: "Konfirmasi password tidak sama.",
    path: ["passwordConfirmation"],
  });

export const onboardingSchema = z.object({
  handle: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z][a-z0-9_]{2,29}$/),
  displayName: z.string().trim().min(2).max(50),
  adultAttestation: z.literal("on"),
  termsAcceptance: z.literal("on"),
});

export const profileUpdateSchema = z.object({
  handle: z
    .string()
    .trim()
    .toLowerCase()
    .regex(/^[a-z][a-z0-9_]{2,29}$/),
  displayName: z.string().trim().min(2).max(50),
  bio: z.string().trim().max(280),
});

export type OnboardingInput = z.infer<typeof onboardingSchema>;

export function onboardingRpcInput(input: OnboardingInput) {
  return {
    requested_handle: input.handle,
    requested_display_name: input.displayName,
    accepted_age_version: AGE_ATTESTATION_VERSION,
    accepted_terms_version: TERMS_VERSION,
  } as const;
}
