import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import { getPublicEnv } from "@/shared/config/env";

const protectedPrefixes = ["/account", "/onboarding", "/auth/update-password", "/spaces"];
const authCacheHeaders = ["cache-control", "expires", "pragma"] as const;

function copyAuthState(source: NextResponse, target: NextResponse) {
  source.cookies.getAll().forEach((cookie) => target.cookies.set(cookie));
  authCacheHeaders.forEach((header) => {
    const value = source.headers.get(header);
    if (value) target.headers.set(header, value);
  });
  return target;
}

export async function refreshAuthSession(request: NextRequest) {
  const env = getPublicEnv();
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet, headersToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));

          const nextResponse = NextResponse.next({ request });
          copyAuthState(response, nextResponse);
          cookiesToSet.forEach(({ name, value, options }) => {
            nextResponse.cookies.set(name, value, options);
          });
          Object.entries(headersToSet).forEach(([name, value]) => {
            nextResponse.headers.set(name, value);
          });
          response = nextResponse;
        },
      },
    },
  );

  const { data } = await supabase.auth.getClaims();
  const isProtected = protectedPrefixes.some((prefix) =>
    request.nextUrl.pathname.startsWith(prefix),
  );

  if (isProtected && !data?.claims.sub) {
    const signInUrl = new URL("/auth/sign-in", request.url);
    signInUrl.searchParams.set(
      "next",
      `${request.nextUrl.pathname}${request.nextUrl.search}`,
    );
    return copyAuthState(response, NextResponse.redirect(signInUrl));
  }

  return response;
}
