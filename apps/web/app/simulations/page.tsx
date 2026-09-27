
import { auth } from "@/auth";

export default async function SimulationsPage() {
  const session = await auth();
  if (!session) return <p>Non connecté - <a href="/login">Login</a></p>;

  return (
    <main style={{ padding: 24 }}>
      <h1>TENΛ — Simulations What-If (Isolées)</h1>
      <p>Simulations totalement séparées des données réelles. Aucune Transaction réelle modifiée.</p>

      <section style={{ border: '1px solid #7C3AED', padding: 16, marginTop: 16 }}>
        <h2>Créer un scénario</h2>
        <form>
          <input placeholder="Nom scénario ex: Achat voiture" />
          <button type="button">Créer scénario (sim_)</button>
        </form>
        <p>Namespace: sim_ / simtx_ - jamais tx_ - isolation garantie</p>
      </section>

      <section style={{ border: '1px solid #ccc', padding: 16, marginTop: 16 }}>
        <h2>Impact</h2>
        <p>Calcul Int centimes: réel + simulation = combiné, sans Float</p>
        <p>Exemple: Réel 100000c + Sim 500000c = 600000c, diff 500000c, diffPercent 500%</p>
      </section>

      <p style={{ color: 'green' }}>Libs: aucune - logique pure core/simulation/advanced.ts</p>
    </main>
  );
}
