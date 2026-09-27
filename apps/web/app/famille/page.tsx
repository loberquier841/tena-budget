
import { auth } from "@/auth";
import { can } from "@tena/core/src/permissions/permissions";

export default async function FamillePage() {
  const session = await auth();
  if (!session) return <p>Non connecté — <a href="/login">Login</a></p>;
  const role = "owner" as const; // TODO: fetch from DB
  return (
    <main>
      <h1>Famille — Gestion membres</h1>
      <p>Connecté: {(session as any).userId}</p>
      <p>Peut inviter: {can(role, "budget:write") ? "oui" : "non"}</p>
      <p>Limite appareils: 3 max par utilisateur — vérifiée côté serveur via canRegisterDevice()</p>
    </main>
  );
}
