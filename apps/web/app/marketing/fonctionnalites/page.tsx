import { APP_NAME } from '@tena/shared';
import Link from 'next/link';

export default function FeaturesPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Fonctionnalités
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Toutes les fonctionnalités dont vous avez besoin pour gérer vos finances, stockées
        localement sur votre appareil.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Transactions</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Enregistrez, catégorisez et suivez chaque transaction — revenues et dépenses.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Saisie manuelle rapide</li>
          <li>Catégorisation automatique suggérée</li>
          <li>Recherche et filtres par date, catégorie, montant</li>
          <li>Suppression sensible avec confirmation</li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Budgets</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Créez des budgets par catégorie et suivez votre consommation en temps réel.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Budgets périodiques (mensuels, trimestriels, annuels)</li>
          <li>Comparaison dépensé vs budget</li>
          <li>Alertes lorsque vous approchez de la limite</li>
          <li>Budgets individuels et familiaux</li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Objectifs d'épargne</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Définissez une cible d'épargne et suivez votre progression visuelle.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Cible en euros ou en centimes</li>
          <li>Barre de progression visuelle</li>
          <li>Historique des tentatives passées</li>
          <li>Périodes d'épargne personnalisables</li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Rapports</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Obtenez des aperçus de votre situation financière sans quitter l'application.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>Résumé des revenus et dépenses</li>
          <li>Répartition par catégorie</li>
          <li>Progression vers les objectifs</li>
          <li>Export au format CSV pour import externe</li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 16 }}>Hors ligne</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Toutes les fonctionnalités fonctionnent sans connexion internet.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>IndexedDB local — aucune dépendance serveur</li>
          <li>Modification et saisie en mode hors ligne</li>
          <li>Synchronisation manuelle à votre initiative</li>
          <li>Sauvegarde et export à tout moment</li>
        </ul>
      </section>

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/telechargements" style={{ background: '#7C3AED', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Accéder à l'application
        </Link>
      </div>
    </main>
  );
}
