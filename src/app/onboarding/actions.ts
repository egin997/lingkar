"use server";

import { redirect } from "next/navigation";

import {
  onboardingRpcInput,
  onboardingSchema,
} from "@/modules/identity/domain/identity";
import { createServerSupabaseClient } from "@/shared/supabase/server";

function onboardingLocation(status: string) {
  return `/onboarding?${new URLSearchParams({ status }).toString()}`;
}

export async function completeOnboardingAction(formData: FormData) {
  const parsed = onboardingSchema.safeParse({
    handle: formData.get("handle"),
    displayName: formData.get("displayName"),
    adultAttestation: formData.get("adultAttestation"),
    termsAcceptance: formData.get("termsAcceptance"),
  });

  if (!parsed.success) redirect(onboardingLocation("invalid_input"));

  const supabase = await createServerSupabaseClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();

  if (userError || !userData.user) redirect("/auth/sign-in?status=session_expired");

  const { error } = await supabase.rpc(
    "complete_identity_onboarding",
    onboardingRpcInput(parsed.data),
  );

  if (error?.code === "23505") redirect(onboardingLocation("handle_unavailable"));
  if (error) redirect(onboardingLocation("onboarding_failed"));

  redirect("/account?status=onboarding_complete");
}
