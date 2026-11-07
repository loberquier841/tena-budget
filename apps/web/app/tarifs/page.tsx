export const metadata = {
  title: 'Tarifs',
  description: 'État des offres TENΛ Budget — transparence, aucune formule fictive activée.',
};

export default function TarifsPage() {
  return (
    <main style={{ maxWidth: 880, margin: '0 auto', padding: '48px 20px', color: '#f5f5f7' }}>
      <h1 style={{ fontSize: 34, margin: '0 0 8px' }}>Tarifs</h1>
      <p style={{ color: '#a0a0ab', lineHeight: 1.6 }}>
        Aucune offre payante, abonnement ou achat intégré n’est activé ou facturé à ce stade.
        Les fonctionnalités locales disponibles (transactions, budgets, objectifs, prévisions, import CSV, sauvegardes chiffrées, justificatifs) fonctionnent sans serveur obligatoire.
      </p>
      <section style={{ background: '#141416', border: '1px solid #2a2a30', borderRadius: 14, padding: 20, marginTop: 20 }}>
        <h2 style={{ fontSize: 18, margin: '0 0 8px' }}>État actuel</h2>
        <ul style={{ margin: 0, paddingLeft: 18, color: '#c7c7ce', lineHeight: 1.8 }}>
          <li><strong style={{ color: '#f5f5f7' }}>Usage local</strong> — disponible selon build installé ; 0€ côté produit tel que livré ici.</li>
          <li><strong style={{ color: '#f5f5f7' }}>Offres Premium/Famille/Entreprise</strong> — non activées. Aucune promesse de prix ou de disponibilité tant que non implémentées et vérifiées.</li>
          <li><strong style={{ color: '#f5f5f7' }}>Paiements</strong> — aucun flux de paiement intégré.</li>
        </ul>
      </section>
      <p style={{ color: '#8b8b96', fontSize: 13, marginTop: 16 }}>Cette page sera mise à jour uniquement lorsque des offres réelles, testées et conformes seront disponibles.</p>
    </main>
  );
}
