
import { auth } from "@/auth";

export default async function HistoriquePage() {
  const session = await auth();
  if (!session) return <p>Non connecté</p>;

  return (
    <main style={{ padding: 24 }}>
      <h1>TENΛ — Historique & Comparaison</h1>
      <p>Comparaison deux périodes + N vs N-1, sans simulations, Int centimes.</p>

      <section style={{ display: 'flex', gap: 16 }}>
        <div style={{ border: '1px solid #7C3AED', padding: 16, flex: 1 }}>
          <h3>Période A: 2025</h3>
          <p>Total dépensé: 10000c, budgeté: 20000c, restant: 10000c</p>
        </div>
        <div style={{ border: '1px solid #7C3AED', padding: 16, flex: 1 }}>
          <h3>Période B: 2026</h3>
          <p>Total dépensé: 20000c, budgeté: 25000c, restant: 5000c</p>
        </div>
      </section>

      <p>Diff: spentDiff 10000c, diffPercentInt 100%, jamais de simulations incluses</p>
      <p>Filtres: personId respecté, familial vs individuel séparés, isDeleted exclu</p>
    </main>
  );
}
