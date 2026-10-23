import { APP_NAME } from '@tena/shared';
import Link from 'next/link';

export default function FaqPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        FAQ
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Questions fréquentes sur TENΛ Budget.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Utilisation générale</h2>
        <div style={{ marginBottom: 16 }}>
          <details style={{ fontSize: 16, color: '#444' }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Qu'est-ce que "local-first" ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555' }}>
              Toutes les données financières sont stockées sur votre appareil dans le navigateur
              (IndexedDB). Aucune donnée n'est envoyée vers des serveurs externes sans votre consentement.
            </p>
          </details>
          <details style={{ fontSize: 16, color: '#444', marginTop: 16 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Puis-je utiliser l'application sans internet ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Oui, entièrement. TENΛ Budget fonctionne en mode hors ligne complet. Toutes les
              fonctionnalités sont disponibles sans connexion internet. Les modifications sont
              synchronisées lorsque vous reconnectez.
            </p>
          </details>
          <details style={{ fontSize: 16, color: '#444', marginTop: 16 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Mes données sont-elles sécurisées ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Vos données sont stockées localement. Nous n'avons aucun accès à vos données financières.
              Le chiffrement des champs sensibles (catégories, noms d'objectifs) est activé par défaut.
            </p>
          </details>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Sauvegardes et appareils</h2>
        <div style={{ marginBottom: 16 }}>
          <details style={{ fontSize: 16, color: '#444' }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Comment sauvegarder mes données ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Utilisez la fonction d'export CSV dans l'application. Le fichier export contient
              toutes vos données et peut être importé sur un nouvel appareil.
            </p>
          </details>
          <details style={{ fontSize: 16, color: '#444', marginTop: 16 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Que se passe-t-il si je change d'appareil ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Exportez vos données depuis l'ancien appareil et importez-les sur le nouvel appareil.
              Il n'y a pas de synchronisation automatique ni de compte cloud requis.
            </p>
          </details>
          <details style={{ fontSize: 16, color: '#444', marginTop: 16 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Les données se synchronisent-elles entre plusieurs appareils ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Non, il n'y a pas de synchronisation automatique entre appareils. Chaque appareil
              stocke ses propres données localement. Utilisez l'export/import pour transférer
              vos données entre appareils.
            </p>
          </details>
        </div>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Offres et abonnements</h2>
        <div style={{ marginBottom: 16 }}>
          <details style={{ fontSize: 16, color: '#444' }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>L'application Free est-elle gratuite à vie ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Oui, l'offre Free est gratuite à vie avec les fonctionnalités de base. Aucune
              carte bancaire n'est requise pour commencer.
            </p>
          </details>
          <details style={{ fontSize: 16, color: '#444', marginTop: 16 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Comment résilier mon abonnement ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Depuis l'application, allez dans les paramètres d'abonnement. La résiliation
              peut être effectuée à tout moment. Pour les abonnements via les stores
              (App Store, Google Play), suivez les procédures du store concerné.
            </p>
          </details>
        </div>
        <div>
          <details style={{ fontSize: 16, color: '#444', marginTop: 16 }}>
            <summary style={{ cursor: 'pointer', fontWeight: 700 }}>Les offres Famille à 12,99 € sont-elles toujours disponibles ?</summary>
            <p style={{ margin: '0 0 8 0', color: '#555'}}>
              Le tarif Famille de référence est de 12,99 € pour l'offre Plus. Vérifiez la page
              des offres pour les informations les plus récentes sur la disponibilité.
            </p>
          </details>
        </div>
      </section>

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/" style={{ background: '#1A1A1B', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Retour à l'accueil
        </Link>
      </div>
    </main>
  );
}
