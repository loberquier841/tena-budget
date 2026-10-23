import { APP_NAME } from '@tena/shared';
import Link from 'next/link';

export default function SecurityPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Sécurité
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Vos données financières sont protégées par plusieurs couches de sécurité.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Chiffrement des données</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            <strong>Chiffrement AES-GCM</strong> — Les champs sensibles (catégories, noms d'objectifs)
            sont chiffrés avant stockage using CryptoService avec des clés dérivées localement.
          </li>
          <li>
            <strong>Clés locales</strong> — Les clés de chiffrement sont générées et stockées
            dans le IndexedDB de votre navigateur. Elles ne quittent jamais votre appareil.
          </li>
          <li>
            <strong>Mise à jour progressive</strong> — Les données existantes sans préfixe de chiffrement
            ('tena1:') sont lues en clair ; de nouvelles données sont automatiquement chiffrées.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Isolation utilisateur</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Chaque utilisateur dispose de son propre jeu de données isolé dans la base de données
            SQLite via la colonne userId DEFAULT 'primary'.
          </li>
          <li>
            Les données d'une famille sont isolées des autres familles via familyId.
          </li>
          <li>
            Les transactions, budgets et objectifs sont étiquetés par userId pour éviter les
            fuites croisées entre utilisateurs sur le même appareil.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Authentification et verrouillage</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          L'application propose un verrouillage PIN/biométrie optionnel au démarrage.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Verrouillage volontaire à l'ouverture de l'application ou après période d'inactivité.
          </li>
          <li>
            Stockage du PIN dans flutter_secure_storage (Keychain iOS / Keystore Android) lorsqu'
            le verrouillage est activé.
          </li>
          <li>
            Le verrouillage est une barrière UI — les données restent chiffrées en base même si
            le verrouillage est désactivé.
          </li>
          <li>
            Note : Le verrouillage application (E1) est documenté pour une future implémentation.
            Les dépendances flutter_secure_storage sont déjà présentes dans le projet.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Sauvegarde et récupération</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Les exports CSV contiennent vos données au complet. Conservez vos exports dans un
            endroit sûr — ils représentent l'intégralité de vos données financières.
          </li>
          <li>
            En cas de perte de appareil, restaurez vos données depuis un export CSV précédent
            sur votre nouvel appareil.
          </li>
          <li>
            Il n'y a pas de "mot de passe maître" requis pour accéder aux données — l'accès
            dépend de la sécurité de l'appareil et du navigateur.
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
