import { APP_NAME, APP_VERSION } from '@tena/shared';
import Link from 'next/link';

export default function Home() {
  const handleWaitlistSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const form = e.target as HTMLFormElement;
    const emailInput = form.querySelector('#waitlist-email') as HTMLInputElement;
    const statusDiv = form.querySelector('#form-status') as HTMLDivElement;
    const email = emailInput.value.trim();
    
    if (!email) return;
    
    // Stocker l'email en localStorage
    const emails = JSON.parse(localStorage.getItem('tena_waitlist_emails') || '[]');
    emails.push(email);
    localStorage.setItem('tena_waitlist_emails', JSON.stringify(emails));
    
    // Afficher le statut
    emailInput.value = '';
    statusDiv.style.display = 'block';
    statusDiv.style.background = '#d1f2eb';
    statusDiv.style.color = '#059669';
    statusDiv.innerHTML = `✓ Merci ! Vous êtes sur la liste d'attente pour TENΛ Budget ${APP_VERSION}.`;
  };

  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 48, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        TENΛ Budget
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Gestion budgétaire personnelle — Hors ligne • Local-first • AUCUN serveur central obligatoire
      </p>

      {/* Section: Qu'est-ce que TENΛ Budget ? */}
      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 32, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>
          Qu'est-ce que TENΛ Budget ?
        </h2>
        <p style={{ fontSize: 18, color: '#444', lineHeight: 1.8 }}>
          TENΛ Budget est une application de gestion budgétaire qui s'exécute directement dans votre navigateur
          ou sur votre appareil. Toutes vos données financières sont stockées localement — aucune
          n'est envoyée vers des serveurs tiers sans votre consentement explicite.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 16, lineHeight: 1.8 }}>
          <li>Gestion des transactions (dépenses & revenus)</li>
          <li>Budgets personnalisés par catégorie</li>
          <li>Objectifs d'épargne avec suivi de progression</li>
          <li>Rapports et visualisations financières</li>
        </ul>
      </section>

      {/* Section: À qui sert-il ? */}
      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 32, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>
          À qui sert-il ?
        </h2>
        <p style={{ fontSize: 18, color: '#444', lineHeight: 1.8 }}>
          Idéal pour les particuliers et les familles qui veulent prendre le contrôle de leurs finances
          sans dépendre d'un service cloud obligatoire. Que vous soyez sur mobile, tablette ou ordinateur,
          vos données vous appartiennent entièrement.
        </p>
      </section>

      {/* Section: Que peut-on faire ? */}
      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 32, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>
          Que pouvez-vous faire ?
        </h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit', minmax(200px, 1fr))', gap: 16, marginTop: 24 }}>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb', textAlign: 'center' }}>
            <div style={{ fontSize: 48, marginBottom: 8 }}>📊</div>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#7C3AED', marginBottom: 4 }}>Transactions</h3>
            <p style={{ color: '#666', fontSize: 14 }}>Enregistrez vos dépenses et revenus</p>
          </div>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb', textAlign: 'center' }}>
            <div style={{ fontSize: 48, marginBottom: 8 }}>💰</div>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#22c55e', marginBottom: 4 }}>Budgets</h3>
            <p style={{ color: '#666', fontSize: 14 }}>Définissez et suivez vos budgets</p>
          </div>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb', textAlign: 'center' }}>
            <div style={{ fontSize: 48, marginBottom: 8 }}>🎯</div>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#f59e0b', marginBottom: 4 }}>Objectifs</h3>
            <p style={{ color: '#666', fontSize: 14 }}>Épargnez vers une cible</p>
          </div>
        </div>
      </section>

      {/* Section: Pourquoi choisir TENΛ Budget ? */}
      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 32, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>
          Pourquoi choisir TENΛ Budget ?
        </h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit', minmax(180px, 1fr))', gap: 16, marginTop: 24 }}>
          <div style={{ background: '#eef2ff', padding: 20, borderRadius: 10, border: '1px solid #7c3aed' }}>
            <div style={{ fontSize: 24, marginBottom: 8 }}>🔒</div>
            <div>
              <strong>Vos données vous appartiennent</strong><br/>
              <small>Aucun serveur central, tout est local</small>
            </div>
          </div>
          <div style={{ background: '#eef2ff', padding: 20, borderRadius: 10, border: '1px solid #7c3aed' }}>
            <div style={{ fontSize: 24, marginBottom: 8 }}>🌐</div>
            <div>
              <strong>Hors ligne complet</strong><br/>
              <small>Toutes les fonctionnalités sans internet</small>
            </div>
          </div>
          <div style={{ background: '#eef2ff', padding: 20, borderRadius: 10, border: '1px solid #7c3aed' }}>
            <div style={{ fontSize: 24, marginBottom: 8 }}>💰</div>
            <div>
              <strong>Pas d'abligation cachée</strong><br/>
              <small>Tarifs transparents, pas de surprise</small>
            </div>
          </div>
        </div>
      </section>

      {/* Appel à l'action principal */}
      <div style={{ margin: 32 0, textAlign: 'center' }}>
        <Link href="/offres" style={{ 
          background: '#7C3AED', 
          color: 'white', 
          padding: '20px 40px', 
          borderRadius: 12, 
          textDecoration: 'none', 
          fontSize: 20, 
          fontWeight: 700,
          display: 'inline-block'
        }}>
          Découvrir les offres et tarifs
        </Link>
      </div>

      {/* Section: Rejoindre la liste d'attente */}
      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 32, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Rejoindre la liste d'attente</h2>
        <p style={{ fontSize: 18, color: '#444', lineHeight: 1.8 }}>
          Soyez informé(e) de la sortie de la version 1.0, des nouvelles offres et des mises à jour importantes. Aucune donnée n'est partagée avec des tiers.
        </p>
        <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb', maxWidth: 480, margin: 0 auto }}>
          <form id="waitlist-form" onSubmit={handleWaitlistSubmit} style={{ display: 'grid', gap: 16 }}>
            <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '1fr 1fr' }}>
              <input type="email" id="waitlist-email" placeholder="votre@email.com" required style={{ padding: '12px 16px', border: '1px solid #d1d5db', borderRadius: 8, fontSize: 16, outline: 'none' }} />
              <button type="submit" style={{ background: '#7C3AED', color: 'white', padding: '12px 24px', border: 'none', borderRadius: 8, fontSize: 16, fontWeight: 700, cursor: 'pointer' }}>S'inscrire</button>
            </div>
            <p style={{ color: '#666', fontSize: 13, textAlign: 'center' }}>
              Nous respectons votre vie privée. Vous pouvez vous désabonner à tout moment.
            </p>
          </form>
          <div id="form-status" style={{ padding: 16, borderRadius: 8, marginTop: 16, display: 'none', fontSize: 14 }}>
            <!-- Statut du formulaire inséré par JS -->
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer style={{ marginTop: 64, padding: 32, background: '#0A0A0B', color: 'white', borderTop: '4px solid #7C3AED' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit', minmax(200px, 1fr))', gap: 32, marginBottom: 32 }}>
          <div>
            <h4 style={{ fontSize: 18, fontWeight: 700, color: '#7C3AED', marginBottom: 16 }}>TENΛ Budget</h4>
            <p style={{ fontSize: 14, color: '#888', lineHeight: 1.6 }}>
              Gestion budgétaire locale-first • Hors ligne • Vos données vous appartiennent
            </p>
          </div>
          <div>
            <h4 style={{ fontSize: 18, fontWeight: 700, color: '#7C3AED', marginBottom: 16 }}>Navigation</h4>
            <ul style={{ listStyle: 'none', padding: 0, color: '#888', fontSize: 14, lineHeight: 1.8 }}>
              <li><Link href="/fonctionnalites" style={{ color: '#888', textDecoration: 'none' }}>Fonctionnalités</Link></li>
              <li><Link href="/offres" style={{ color: '#888', textDecoration: 'none' }}>Offres</Link></li>
              <li><Link href="/telechargements" style={{ color: '#888', textDecoration: 'none' }}>Téléchargements</Link></li>
              <li><Link href="/confidentialite" style={{ color: '#888', textDecoration: 'none' }}>Confidentialité</Link></li>
            </ul>
          </div>
          <div>
            <h4 style={{ fontSize: 18, fontWeight: 700, color: '#7C3AED', marginBottom: 16 }}>Ressources</h4>
            <ul style={{ listStyle: 'none', padding: 0, color: '#888', fontSize: 14, lineHeight: 1.8 }}>
              <li><Link href="/documentation" style={{ color: '#888', textDecoration: 'none' }}>Documentation</Link></li>
              <li><Link href="/faq" style={{ color: '#888', textDecoration: 'none' }}>FAQ</Link></li>
              <li><Link href="/a-propos" style={{ color: '#888', textDecoration: 'none' }}>À propos</Link></li>
            </ul>
          </div>
        </div>
        <div style={{ borderTop: '1px solid #333', paddingTop: 24, color: '#666', fontSize: 14, textAlign: 'center' }}>
          <p>© 2024 TENΛ Budget • Version ${APP_VERSION} • Code source disponible</p>
        </div>
      </footer>
    </main>
  );
}
