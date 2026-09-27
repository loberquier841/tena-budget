
import { auth } from "@/auth";
export default auth((req) => {
  // Protection globale - vérification serveur
  const isAuthPage = req.nextUrl.pathname.startsWith("/login");
  const isLogged = !!req.auth;
  if (!isAuthPage && !isLogged && req.nextUrl.pathname !== "/") {
    // En Étape 2 on protège /famille/*
    if (req.nextUrl.pathname.startsWith("/famille")) {
      return Response.redirect(new URL("/login", req.nextUrl));
    }
  }
});
export const config = { matcher: ["/famille/:path*"] };
