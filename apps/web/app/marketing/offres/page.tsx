import { APP_NAME } from '@tena/shared';
import Link from 'next/link';

export default function OffersPage() {
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
    statusDiv.innerHTML = `✓ Merci ! Vous êtes sur la liste d'attente pour TENΛ Budget ${APP_NAME}.`;
  };

  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Offres et tarifs
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Choisissez l'offre qui correspond à vos besoins. Toutes les offres incluent le stockage
        local de vos données — aucune donnée n'est transmise vers des serveurs tiers.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Comparaison des offres</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, marginTop: 24 }}>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Free</h3>
            <ul style={{ margin: 0 0 24 0, paddingLeft: 20, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
              <li>Transactions illimitées</li>
              <li>Catégories de base</li>
              <li>Budgets mensuels</li>
              <li>Objectifs d'épargne</li>
              <li>Rapports CSV</li>
              <li>Hors ligne</li>
            </ul>
            <p style={{ fontSize: 14, color: '#22c55e', fontWeight: 700, marginBottom: 8 }}>Gratuit</p>
            <p style={{ fontSize: 13, color: '#666' }}>Idéal pour commencer</p>
          </div>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Plus</h3>
            <ul style={{ margin: 0 0 24 0, paddingLeft: 20, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
              <li>Tout inclus dans Free</li>
              <li>Budgets avancés</li>
              <li>Objectifs multiples</li>
              <li>Rapports détaillés</li>
              <li>Catégories personnalisées</li>
            </ul>
            <p style={{ fontSize: 14, color: '#22c55e', fontWeight: 700, marginBottom: 8 }}>12,99 € / mois</p>
            <p style={{ fontSize: 13, color: '#666' }}>Tarif Famille confirmé</p>
          </div>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Offres supérieures</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, marginTop: 24 }}>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Pro</h3>
            <ul style={{ margin: 0 0 24 0, paddingLeft: 20, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
              <li>Tout inclus dans Plus</li>
              <li>Catégories avancées</li>
              <li>Objectifs sophistiqués</li>
              <li>Rapports premium</li>
              <li>Priorité assistance</li>
            </ul>
            <p style={{ fontSize: 14, color: '#7c3aed', fontWeight: 700, marginBottom: 8 }}>24,99 € / mois</p>
            <p style={{ fontSize: 13, color: '#666' }}>À partir de</p>
          </div>
          <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb' }}>
            <h3 style={{ fontSize: 20, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Premium</h3>
            <ul style={{ margin: 0 0 24 0, paddingLeft: 20, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
              <li>Tout inclus dans Pro</li>
              <li>Synchronisation multi-appareils (optionnelle)</li>
              <li>Sauvegardes automatiques cryptées</li>
              <li>Assistant IA intégré</li>
              <li>Support prioritaire</li>
            </ul>
            <p style={{ fontSize: 14, color: '#7c3aed', fontWeight: 700, marginBottom: 8 }}>Sur devis</p>
            <p style={{ fontSize: 13, color: '#666' }}>Sur demande</p>
          </div>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Entreprise</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Pour les équipes et les entreprises. Contactez-nous pour un devis personnalisé.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Plusieurs utilisateurs avec rôles</li>
          <li>Budgets d'équipe</li>
          <li>Rapports d'entreprise</li>
          <li>API d'intégration</li>
          <li>Support dédié</li>
        </ul>
      </section>

      {/* Section: Rejoindre la liste d'attente */}
      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Rejoindre la liste d'attente</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Soyez informé(e) de la sortie de la version 1.0, des nouvelles offres et des mises à jour importantes.
          Aucune donnée n'est partagée avec des tiers.
        </p>
        <div style={{ background: 'white', padding: 24, borderRadius: 12, border: '1px solid #e5e7eb', maxWidth: 480, margin: 0 auto }}>
          <form id="waitlist-form" onSubmit={handleWaitlistSubmit} style={{ display: 'grid', gap: 16 }}>
            <div style={{ display: 'grid', gap: 8, gridTemplateColumns: '1fr 1fr' }}>
              <input type="email" id="waitlist-email" placeholder="votre@email.com" required style={{ padding: '12px 16px', border: '1px solid #d1d5db', borderRadius: 8, fontSize: 16, outline: 'none' }} />
              <button type="submit" style={{ background: '#7C3AED', color: 'white', padding: '12px 24px', border: 'none', borderRadius: 8, fontSize: 16, fontWeight: 700, cursor: 'pointer' }}>
                S'inscrire
              </button>
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

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/telechargements" style={{ background: '#7C3AED', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Commencer avec Free
        </Link>
      </div>
    </main>
  );
}
