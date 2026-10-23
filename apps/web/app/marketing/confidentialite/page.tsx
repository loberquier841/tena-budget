import { APP_NAME } from '@tena/shared';
import Link from 'next/link';

export default function PrivacyPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Confidentialité
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Nous respectons votre vie privée. Cette page explique comment nous traitons vos données.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Collecte de données</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Nous ne collectons aucune de vos données financières. Toutes les données sont stockées
            localement dans votre navigateur ou sur votre appareil.
          </li>
          <li>
            Aucune donnée n'est transmise vers nos serveurs, vers des tiers ou vers des services
            d'analyse sans votre accord explicite.
          </li>
          <li>
            Les données de diagnostic volontaires (erreurs d'application, données de performance)
            sont optionnelles et peuvent être désactivées dans les paramètres.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Stockage des données</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Toutes vos données sont stockées dans l'IndexedDB de votre navigateur.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            IndexedDB est une base de donnéesNoSQL locale disponible dans tous les navigateurs modernes.
          </li>
          <li>
            La taille de stockage est limitée par le navigateur (généralement plusieurs Go).
          </li>
          <li>
            Les données persistent entre les sessions de navigateur mais sont spécifiques à chaque
            navigateur et appareil. Chang de navigateur ou de mode privé = nouvelles données.
          </li>
          <li>
            Les champs sensibles (catégories de transactions, noms d'objectifs d'épargne) sont
            chiffrés avant stockage via CryptoService avec préfixe tena1: pour compatibilité progressive.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Partage et export</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          Vous contrôlez entièrement le partage de vos données.
        </p>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            L'export CSV contient vos données financières au format lisible. Vous décidez où
            envoyer le fichier export.
          </li>
          <li>
            L'import CSV vous permet de reintroduire des données que vous avez exportées ou
            reçues d'une autre source.
          </li>
          <li>
            Nous ne recevons jamais de fichiers exportés ni de données importées sauf si vous
            nous les envoyez volontairement via le canal de contact.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Cookies et technologies similaires</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Nous utilisons des cookies strictement nécessaires au fonctionnement du site web
            (session, préférences de langue).
          </li>
          <li>
            Nous n'utilisons pas de cookies de suivi publicitaire ni d'analyse tiers sans votre
            consentement.
          </li>
          <li>
            Vous pouvez gérer les préférences de cookies via votre navigateur.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Enfants</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          TENΛ Budget n'est pas destiné aux enfants de moins de 16 ans. Les parents ou tuteurs
          sont responsables de la supervision de l'utilisation par les mineurs.
        </p>
      </section>

      <div style={{ marginTop: 48, textAlign: 'center' }}>
        <Link href="/" style={{ background: '#1A1A1B', color: 'white', padding: '16px 32px', borderRadius: 10, textDecoration: 'none', fontSize: 18, fontWeight: 700 }}>
          Retour à l'accueil
        </Link>
      </div>
    </main>
  );
}
