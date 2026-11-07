export const metadata = {
  title: 'Téléchargements',
  description: 'État réel des binaires TENΛ Budget. Aucun téléchargement fictif.',
};

export default function DownloadPage() {
  // IMPORTANT: ne jamais afficher de lien/binaire si le fichier n'existe pas et
  // n'est pas vérifié. Aucun faux "disponible".
  const releases = [
    { platform: 'Windows', status: 'Non disponible (binaire non publié/vérifié)', detail: 'Aucun installeur distribué à ce stade. Build/signature à produire et vérifier avant publication.' },
    { platform: 'macOS', status: 'Non disponible (binaire non publié/vérifié)', detail: 'Nécessite Xcode + signature/notarisation. Aucun DMG/PKG distribué.' },
    { platform: 'Linux', status: 'Non disponible (binaire non publié/vérifié)', detail: 'Aucun paquet distribué.' },
    { platform: 'Android / iOS', status: 'Non disponible (publication store non effectuée)', detail: 'Aucun binaire store distribué.' },
  ];

  return (
    <main style={{ maxWidth: 880, margin: '0 auto', padding: '48px 20px', color: '#f5f5f7' }}>
      <h1 style={{ fontSize: 34, margin: '0 0 8px' }}>Téléchargements</h1>
      <p style={{ color: '#a0a0ab', lineHeight: 1.6, marginTop: 0 }}>
        Transparence : aucun binaire n’est proposé tant qu’il n’est pas réellement compilé,
        signé (si requis) et vérifié. L’application financière reste locale/offline.
      </p>

      <section style={{ background: '#141416', border: '1px solid #2a2a30', borderRadius: 14, padding: 20, margin: '20px 0' }}>
        <h2 style={{ fontSize: 18, margin: '0 0 12px' }}>État des plateformes</h2>
        <ul style={{ margin: 0, paddingLeft: 18, color: '#c7c7ce', lineHeight: 1.7 }}>
          {releases.map((r) => (
            <li key={r.platform}><strong style={{ color: '#f5f5f7' }}>{r.platform}</strong> — {r.status}<br /><span style={{ color: '#8b8b96', fontSize: 13 }}>{r.detail}</span></li>
          ))}
        </ul>
      </section>

      <section style={{ background: '#141416', border: '1px solid #2a2a30', borderRadius: 14, padding: 20 }}>
        <h2 style={{ fontSize: 18, margin: '0 0 8px' }}>Sécurité des téléchargements (quand disponibles)</h2>
        <p style={{ color: '#a0a0ab', margin: 0, lineHeight: 1.6 }}>
          Les binaires publiés devront indiquer version, date, empreinte SHA-256 et canal officiel.
          Aucun téléchargement n’est activé sur cette page pour l’instant.
        </p>
      </section>
    </main>
  );
}