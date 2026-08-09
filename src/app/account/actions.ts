"use server";

import { redirect } from "next/navigation";

import { profileUpdateSchema } from "@/modules/identity/domain/identity";
import { createServerSupabaseClient } from "@/shared/supabase/server";

function accountLocation(status: string) {
  return `/account?${new URLSearchParams({ status }).toString()}`;
}

export async function updateProfileAction(formData: FormData) {
  const parsed = profileUpdateSchema.safeParse({
    handle: formData.get("handle"),
    displayName: formData.get("displayName"),
    bio: formData.get("bio"),
  });

  if (!parsed.success) redirect(accountLocation("invalid_profile"));

  const supabase = await createServerSupabaseClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();

  if (userError || !userData.user) redirect("/auth/sign-in?status=session_expired");

  const { error } = await supabase
    .from("profiles")
    .update({
      handle: parsed.data.handle,
      display_name: parsed.data.displayName,
      bio: parsed.data.bio,
    })
    .eq("user_id", userData.user.id);

  if (error?.code === "23505") redirect(accountLocation("handle_unavailable"));
  if (error) redirect(accountLocation("profile_update_failed"));

  redirect(accountLocation("profile_updated"));
}
