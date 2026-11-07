export const metadata = {
  title: 'Sécurité et confidentialité',
  description: 'Comment TENΛ Budget protège les données : local-first, chiffrement, sauvegardes, et limites honnêtes.',
};

export default function SecuritePage() {
  const items = [
    { t: 'Local-first / hors ligne', d: 'L’application financière est conçue pour fonctionner sur votre appareil, sans serveur financier obligatoire. Les données ne sont pas envoyées automatiquement à un service externe.' },
    { t: 'Chiffrement des données sensibles', d: 'Les champs sensibles sont chiffrés (AES-GCM) via le stockage applicatif. Les clés sont gérées localement (keystore/sécurisation plateforme quand disponible). SQLCipher n’est pas activé à ce stade.' },
    { t: 'Sauvegardes chiffrées', d: 'Exports locaux : mode clé locale ou export portable protégé par phrase de passe (dérivation robuste + AES-GCM). La phrase de passe n’est jamais stockée. Validation d’intégrité (empreinte) avant restauration ; sauvegarde de secours avant restauration.' },
    { t: 'Justificatifs', d: 'Fichiers copiés localement avec chemins relatifs en base ; inclus dans les sauvegardes quand présents. Les contenus manquants/corrompus sont signalés, sans perte silencieuse des métadonnées.' },
    { t: 'Limites (transparentes)', d: 'Aucun système n’est infaillible. Protégez l’accès à votre appareil. Si la phrase de passe portable est perdue, le contenu chiffré ne peut pas être récupéré. Les builds/signatures/publications store ne sont pas tous disponibles à ce stade.' },
  ];
  return (
    <main style={{ maxWidth: 880, margin: '0 auto', padding: '48px 20px', color: '#f5f5f7' }}>
      <h1 style={{ fontSize: 34, margin: '0 0 8px' }}>Sécurité & confidentialité</h1>
      <p style={{ color: '#a0a0ab', lineHeight: 1.6 }}>Informations factuelles sur le fonctionnement actuel. Aucune promesse de fonctionnalité non livrée.</p>
      <div style={{ display: 'grid', gap: 12, marginTop: 20 }}>
        {items.map((i) => (
          <section key={i.t} style={{ background: '#141416', border: '1px solid #2a2a30', borderRadius: 14, padding: 18 }}>
            <h2 style={{ fontSize: 17, margin: '0 0 6px' }}>{i.t}</h2>
            <p style={{ margin: 0, color: '#c7c7ce', lineHeight: 1.65 }}>{i.d}</p>
          </section>
        ))}
      </div>
    </main>
  );
}
