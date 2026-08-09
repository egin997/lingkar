import { createServerClient } from "@supabase/ssr";
import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";

import { getPublicEnv } from "@/shared/config/env";
import { safeNextPath } from "@/shared/http/safe-next-path";

const supportedOtpTypes = new Set<EmailOtpType>([
  "email",
  "email_change",
  "invite",
  "magiclink",
  "recovery",
  "signup",
]);

export async function GET(request: NextRequest) {
  const env = getPublicEnv();
  const requestUrl = new URL(request.url);
  const next = safeNextPath(requestUrl.searchParams.get("next"), "/account");
  let response = NextResponse.redirect(new URL(next, requestUrl.origin));

  const supabase = createServerClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet, headersToSet) {
          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });
          Object.entries(headersToSet).forEach(([name, value]) => {
            response.headers.set(name, value);
          });
        },
      },
    },
  );

  const code = requestUrl.searchParams.get("code");
  const tokenHash = requestUrl.searchParams.get("token_hash");
  const requestedType = requestUrl.searchParams.get("type") as EmailOtpType | null;
  let error: unknown;

  if (code) {
    ({ error } = await supabase.auth.exchangeCodeForSession(code));
  } else if (tokenHash && requestedType && supportedOtpTypes.has(requestedType)) {
    ({ error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: requestedType,
    }));
  } else {
    error = new Error("missing_confirmation_parameters");
  }

  if (error) {
    response = NextResponse.redirect(
      new URL("/auth/sign-in?status=confirmation_failed", requestUrl.origin),
    );
  }

  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
