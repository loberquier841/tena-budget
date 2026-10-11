import { auth } from "@/auth";
import { checkRateLimit } from "@/lib/rateLimit";

export default auth(async (req) => {
  const path = req.nextUrl.pathname;

  // Rate limit for authentication attempts
  if (path.startsWith("/api/auth/")) {
    const ip =
      req.ip ??
      req.headers.get("x-forwarded-for") ??
      "unknown";
    const { allowed } = checkRateLimit(ip);
    if (!allowed) {
      return new Response("Too Many Requests", { status: 429 });
    }
    // fall through to NextAuth handler
  }

  // Protection globale - vérification serveur
  const isAuthPage = path.startsWith("/login");
  const isLogged = !!req.auth;
  if (!isAuthPage && !isLogged && path !== "/") {
    // En Étape 2 on protège /famille/*
    if (path.startsWith("/famille")) {
      return Response.redirect(new URL("/login", req.nextUrl));
    }
  }
  // Allow request to proceed to NextAuth or other handlers
});

export const config = { matcher: ["/famille/:path*", "/api/auth/:path*"]; }
