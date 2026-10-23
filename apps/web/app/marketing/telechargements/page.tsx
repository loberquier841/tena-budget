import { APP_NAME, APP_VERSION } from '@tena/shared';
import Link from 'next/link';

export default function DownloadsPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Téléchargements
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Accédez à l'application TENΛ Budget sur votre plateforme. Toutes les versions
        stockent vos données localement — aucune transmission vers des serveurs tiers.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Application Web</h2>
        <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3 style={{ fontSize: 18, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Dans votre navigateur</h3>
          <p style={{ fontSize: 15, color: '#444', lineHeight: 1.8 }}>
            Aucune installation requise. Cliquez ci-dessous pour commencer immédiatement.
          </p>
          <div style={{ marginTop: 24 }}>
            <Link href="/dashboard" style={{ background: '#7C3AED', color: 'white', padding: '12px 24px', borderRadius: 8, textDecoration: 'none', fontSize: 16, fontWeight: 700 }}>
              Démarrer l'application Web
            </Link>
          </div>
          <p style={{ fontSize: 13, color: '#888', marginTop: 16 }}>
            Fonctionne sur Chrome, Firefox, Safari, Edge. Mode hors ligne complet.
          </p>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Desktop</h2>
        <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3 style={{ fontSize: 18, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Windows</h3>
          <ul style={{ margin: 0 0 24 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
            <li>Installateur Windows (.exe)</li>
            <li>Compatible Windows 10 ou version ultérieure</li>
            <li>Espace requis : 200 Mo minimum</li>
            <li>.NET Framework 4.7.2 inclus sous Windows 10</li>
          </ul>
          <p style={{ fontSize: 13, color: '#666', marginBottom: 8 }}>
            Statut : Version de développement — disponible via l'application Web
          </p>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Mobile</h2>
        <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
          <h3 style={{ fontSize: 18, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Responsive Web</h3>
          <p style={{ fontSize: 15, color: '#444', lineHeight: 1.8 }}>
            L'application s'adapte à tous les tailles d'écran — smartphone et tablette.
            Aucun téléchargement spécifique requis pour l'usage basique.
          </p>
          <ul style={{ margin: 0 0 24 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
            <li>iOS — navigateur Safari (mode "Ajouter à l'écran d'accueil" disponible)</li>
            <li>Android — navigateur Chrome (mode "Installer l'application" disponible)</li>
            <li>Toute taille d'écran — mise en page fluide</li>
          </ul>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>État des versions</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit', minmax(200px, 1fr))', gap: 16, marginTop: 24 }}>
          <div style={{ background: '#f0fdf4', padding: 20, borderRadius: 10, border: '1px solid #bbf7d0' }}>
            <div style={{ fontSize: 20, marginBottom: 8 }}'>✓</div>
            <div>
              <strong>Application Web</strong><br/>
              <small>Disponible immédiatement</small>
            </div>
          </div>
          <div style={{ background: '#fffbeb', padding: 20, borderRadius: 10, border: '1px solid #f59e0b' }}>
            <div style={{ fontSize: 20, marginBottom: 8 }}'>⏳</div>
            <div>
              <strong>Windows Desktop</strong><br/>
              <small>En préparation</small>
            </div>
          </div>
          <div style={{ background: '#fffbeb', padding: 20, borderRadius: 10, border: '1px solid #f59e0b' }}>
            <div style={{ fontSize: 20, marginBottom: 8 }}'>⏳</div>
            <div>
              <strong>Application Mobile Native</strong><br/>
              <small>En planification</small>
            </div>
          </div>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Comment ça marche</h2>
        <ol style={{ margin: 0 0 0 24, padding: 0, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Choisissez votre plateforme ci-dessus</li>
          <li>Cliquez sur le lien de téléchargement ou d'accès immédiat</li>
          <li>L'application s'installe ou s'ouvre dans votre navigateur</li>
          <li>Toutes vos données restent sur votre appareil</li>
          <li>Aucun compte ni inscription requis pour commencer</li>
        </ol>
      </section>

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/" style={{ background: '#1A1A1B', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Retour à l'accueil
        </Link>
      </div>
    </main>
  );
}
