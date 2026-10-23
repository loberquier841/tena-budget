import { APP_NAME, APP_VERSION } from '@tena/shared';
import Link from 'next/link';

export default function AboutPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        À propos de TENΛ Budget
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        L'histoire et la vision du projet.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Notre mission</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Permettre à chaque particulier et famille de prendre le contrôle de ses finances sans
          dépendre de serveurs centraux obligatoires ni de tiers de confiance.
        </p>
        <blockquote style={{ margin: '24 0 24 0', paddingLeft: 24, borderLeft: '4px solid #7C3AED', color: '#555', fontSize: 16, lineHeight: 1.8 }}>
          <p>"Vos données financières vous appartiennent — point final."</p>
        </blockquote>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Historique</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          TENΛ Budget a débuté comme un projet de gestion budgétaire personnelle visant à
          démontrer qu'il est possible d'avoir des fonctionnalités complètes de gestion financière
          sans base de données cloud obligatoire. Le projet privilégie une approche
          "local-first" où les données de l'utilisateur lui appartiennent entièrement.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Début du projet : début 2024</li>
          <li>Version actuelle : ${APP_VERSION}</li>
          <li>Étape en cours : Fondation (20 étapes au total)</li>
          <li>Public ciblé : Particuliers et familles</li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Philosophie de développement</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            <strong>Local-first :</strong> Les données appartiennent à l'utilisateur, pas à un serveur.
          </li>
          <li>
            <strong>Hors ligne par défaut :</strong> Toutes les fonctionnalités fonctionnent sans internet.
          </li>
          <li>
            <strong>Transparence :</strong> Aucun service payant obligatoire pour utiliser le noyau
            de l'application.
          </li>
          <li>
            <strong>Accessibilité :</strong> L'application Web fonctionne dans n'importe quel navigateur
            moderne sans installation requise.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>État actuel</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          L'application est à l'étape 9/20 du plan de développement. Les fonctionnalités de base
          (transactions, budgets, objectifs) sont opérationnelles en mode hors ligne. Les étapes
          restantes portent sur l'affinement, les fonctionnalités professionnelles et le déploiement.
        </p>
        <p style={{ fontSize: 17, color: '#444', marginTop: 16, lineHeight: 1.8 }}>
          L'offre Free est disponible immédiatement sans conditions. Les offres supérieures
          (Plus, Pro, Premium) sont disponibles pour les utilisateurs qui souhaitent soutenir
          le projet ou accéder à des fonctionnalités avancées.
        </p>
      </section>

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/telechargements" style={{ background: '#7C3AED', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Accéder à l'application
        </Link>
      </div>
    </main>
  );
}
