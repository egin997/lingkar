"use server";

import { redirect } from "next/navigation";

import {
  passwordUpdateSchema,
  recoverySchema,
  signInSchema,
} from "@/modules/identity/domain/identity";
import { getPublicEnv } from "@/shared/config/env";
import { safeNextPath } from "@/shared/http/safe-next-path";
import { createServerSupabaseClient } from "@/shared/supabase/server";

function authLocation(path: string, code: string, next?: string) {
  const params = new URLSearchParams({ status: code });
  if (next) params.set("next", next);
  return `${path}?${params.toString()}`;
}

export async function signInAction(formData: FormData) {
  const next = safeNextPath(
    typeof formData.get("next") === "string" ? (formData.get("next") as string) : null,
    "/account",
  );
  const parsed = signInSchema.safeParse({
    email: formData.get("email"),
    password: formData.get("password"),
  });

  if (!parsed.success) redirect(authLocation("/auth/sign-in", "invalid_input", next));

  const supabase = await createServerSupabaseClient();
  const { error } = await supabase.auth.signInWithPassword(parsed.data);

  if (error) redirect(authLocation("/auth/sign-in", "invalid_credentials", next));
  redirect(next);
}

export async function requestRecoveryAction(formData: FormData) {
  const parsed = recoverySchema.safeParse({ email: formData.get("email") });

  if (!parsed.success) redirect(authLocation("/auth/recovery", "invalid_email"));

  const env = getPublicEnv();
  const callback = new URL("/auth/confirm", env.NEXT_PUBLIC_SITE_URL);
  callback.searchParams.set("next", "/auth/update-password");

  const supabase = await createServerSupabaseClient();
  await supabase.auth.resetPasswordForEmail(parsed.data.email, {
    redirectTo: callback.toString(),
  });

  // Always return the same result to avoid revealing whether an email is registered.
  redirect(authLocation("/auth/recovery", "recovery_requested"));
}

export async function updatePasswordAction(formData: FormData) {
  const parsed = passwordUpdateSchema.safeParse({
    password: formData.get("password"),
    passwordConfirmation: formData.get("passwordConfirmation"),
  });

  if (!parsed.success) redirect(authLocation("/auth/update-password", "weak_password"));

  const supabase = await createServerSupabaseClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();

  if (userError || !userData.user) redirect(authLocation("/auth/sign-in", "session_expired"));

  const { error } = await supabase.auth.updateUser({ password: parsed.data.password });
  if (error) redirect(authLocation("/auth/update-password", "password_update_failed"));

  redirect(authLocation("/account", "password_updated"));
}

export async function signOutAction() {
  const supabase = await createServerSupabaseClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect(authLocation("/auth/sign-in", "signed_out"));
}
