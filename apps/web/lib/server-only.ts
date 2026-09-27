
import "server-only";
// Ce fichier garantit que les secrets ne fuient jamais côté client
export function getServerSecrets() {
  const secret = process.env.AUTH_SECRET;
  const dbUrl = process.env.DATABASE_URL;
  if (!secret) throw new Error("AUTH_SECRET manquant côté serveur");
  if (!dbUrl) throw new Error("DATABASE_URL manquant côté serveur");
  return { secret, dbUrl };
}
