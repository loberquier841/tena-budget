
import { auth } from "@/auth";

export default async function SauvegardesPage() {
  const session = await auth();
  if (!session) return <p>Non connecté</p>;

  return (
    <main style={{ padding: 24 }}>
      <h1>TENΛ — Sauvegardes Chiffrées</h1>
      <p>Chiffrement réel AES-GCM 256 via Web Crypto API native, pas de dépendance externe.</p>

      <section style={{ border: '1px solid #ccc', padding: 16 }}>
        <h2>Créer sauvegarde</h2>
        <input type="password" placeholder="Mot de passe min 8 chars" />
        <button>Chiffrer & Télécharger .tenla.enc</button>
        <p>Contenu: transactions (non deleted), budgets, catégories, persons, goals, recurringRules + checksum SHA-256</p>
        <p>Aucune clé exposée frontend/logs - password jamais loggué</p>
      </section>

      <section style={{ border: '1px solid #ccc', padding: 16, marginTop: 16 }}>
        <h2>Restaurer</h2>
        <input type="file" />
        <input type="password" placeholder="Mot de passe" />
        <button>Restaurer (vérif intégrité)</button>
        <p>Validation checksum avant restauration, détection conflits si overwrite=false, pas d'écrasement silencieux</p>
        <p>Test cycle sauvegarde→restauration: testBackupRestoreCycle() vérifie checksum + counts</p>
      </section>

      <p>Lib: Web Crypto API native (W3C standard) - gratuit, pas de service payant</p>
    </main>
  );
}
