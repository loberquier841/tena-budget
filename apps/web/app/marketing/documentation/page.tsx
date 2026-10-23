import { APP_NAME, APP_VERSION, APP_ROLES, TRANSACTION_SOURCES, toCents, fromCents } from '@tena/shared';
import Link from 'next/link';

export default function DocumentationPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Documentation
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Guide de démarrage rapide pour TENΛ Budget.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Premier lancement</h2>
        <ol style={{ margin: '0 0 0 24', padding: 0, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Accédez à l'application via le lien « Accéder à l'application » sur la page d'accueil
            ou visitez directement /dashboard.
          </li>
          <li>
            L'application s'ouvre dans votre navigateur. Aucune inscription ni compte n'est requis
            pour commencer à utiliser les fonctionnalités de base.
          </li>
          <li>
            Commencez par ajouter votre première transaction ou créer un budget. Toutes les
            données sont stockées immédiatement dans IndexedDB de votre navigateur.
          </li>
        </ol>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Questionnaire financier</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Au premier lancement, un questionnaire court vous aide à configurer votre profil
          budgétaire de base.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Nombre de personnes dans le foyer</li>
          <li>Sources de revenus principales</li>
          <li>Catégories de dépenses habituelles</li>
          <li>Objectifs d'épargne intéressants</li>
        </ul>
        <p style={{ marginTop: 24, fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Les réponses au questionnaire sont stockées localement et peuvent être modifiées
          à tout moment dans les paramètres.
        </p>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Données locales</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Toutes vos données financières sont stockées dans l'IndexedDB de votre navigateur.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Espace de stockage : dépend de votre navigateur (généralement plusieurs Go)</li>
          <li>Types de données : transactions, budgets, objectifs, profils</li>
          <li>Format : Base de données NoSQL locale via Dexie.js</li>
          <li>Chiffrement : Champs sensibles (catégories, noms d'objectifs) chiffrés avec CryptoService</li>
        </ul>
        <p style={{ marginTop: 24, fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Les données de base (montants, dates, libellés) sont stockées en clair pour des
          raisons de performance, tandis que les champs sensibles sont protégés.
        </p>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Exports et imports</h2>
        <ol style={{ margin: '0 0 0 24', padding: 0, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Pour exporter : Allez dans le menu Exports et sélectionnez CSV. Le fichier contient
            toutes vos données au format compatible avec Excel, Google Sheets, etc.
          </li>
          <li>
            Pour importer : Utilisez la fonction d'import CSV depuis le menu principal.
            Le fichier doit être au format CSV avec les en-têtes attendus.
          </li>
          <li>
            L'import ne remplace pas vos données existantes par défaut — il offre de fusionner
            ou de créer de nouveaux enregistrements.
          </li>
        </ol>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Limites connues</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Pas de synchronisation automatique entre appareils — utilisez l'export/import manuel
          </li>
          <li>
            Fonctionnalités bancaires réelles non implémentées (import de relevés bancaires)
          </li>
          <li>
            Assistant IA en phase de développement — disponible dans l'offre Premium sur devis
          </li>
          <li>
            Applications natives iOS/Android non encore publiées — utilisation via navigateur
          </li>
        </ul>
      </section>

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/" style={{ background: '#1A1A1B', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Retour à l'accueil
        </Link>
      </div>
    </main>
  );
}
