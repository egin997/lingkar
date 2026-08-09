import type { NextRequest } from "next/server";

import { refreshAuthSession } from "@/shared/supabase/proxy";

// OpenNext Cloudflare 1.20.2 does not support Next.js 16 Node Proxy yet.
// Keep the deprecated convention intentionally so this auth boundary runs at the edge.
export async function middleware(request: NextRequest) {
  return refreshAuthSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
