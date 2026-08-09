import type { NextRequest } from "next/server";

import { refreshAuthSession } from "@/shared/supabase/proxy";

// Cloudflare OpenNext does not yet support Next.js 16 Node Proxy. Keeping the
// deprecated Middleware convention intentionally compiles this boundary for Edge.
export async function middleware(request: NextRequest) {
  return refreshAuthSession(request);
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
