import "server-only";

import { createServerSupabaseClient } from "@/shared/supabase/server";

export interface ViewerIdentity {
  readonly userId: string;
  readonly onboardingCompleted: boolean;
  readonly profile: {
    readonly handle: string;
    readonly displayName: string;
    readonly bio: string;
  } | null;
}

export async function getViewerIdentity(): Promise<ViewerIdentity | null> {
  const supabase = await createServerSupabaseClient();
  const { data: claimsData, error: claimsError } = await supabase.auth.getClaims();

  if (claimsError || !claimsData?.claims.sub) return null;

  const userId = claimsData.claims.sub;
  const [accountResult, profileResult] = await Promise.all([
    supabase
      .from("identity_accounts")
      .select("onboarding_completed_at")
      .eq("user_id", userId)
      .maybeSingle(),
    supabase
      .from("profiles")
      .select("handle, display_name, bio")
      .eq("user_id", userId)
      .maybeSingle(),
  ]);

  if (accountResult.error) throw accountResult.error;
  if (profileResult.error) throw profileResult.error;

  const profile = profileResult.data
    ? {
        handle: profileResult.data.handle as string,
        displayName: profileResult.data.display_name as string,
        bio: profileResult.data.bio as string,
      }
    : null;

  return {
    userId,
    onboardingCompleted: Boolean(
      accountResult.data?.onboarding_completed_at && profileResult.data,
    ),
    profile,
  };
}
