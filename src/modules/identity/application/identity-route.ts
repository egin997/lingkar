export interface IdentityProgress {
  readonly authenticated: boolean;
  readonly onboardingCompleted: boolean;
}

export function identityRoute(progress: IdentityProgress): string {
  if (!progress.authenticated) return "/auth/sign-in";
  if (!progress.onboardingCompleted) return "/onboarding";
  return "/account";
}
