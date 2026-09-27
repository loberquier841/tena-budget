
import { signIn } from "@/auth";

export default function LoginPage() {
  return (
    <main style={{ padding: 24 }}>
      <h1>TENΛ Budget — Connexion</h1>
      <form action={async (formData) => {
        "use server";
        await signIn("credentials", { email: formData.get("email"), password: formData.get("password"), redirectTo: "/" });
      }}>
        <input name="email" type="email" placeholder="Email" required />
        <input name="password" type="password" placeholder="Mot de passe (min 8)" required minLength={8} />
        <button type="submit">Se connecter</button>
      </form>
      <p>Aucun mot de passe stocké en clair. Bcrypt 12 côté serveur.</p>
    </main>
  );
}
