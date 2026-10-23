import { APP_NAME } from '@tena/shared';
import Link from 'next/link';

export default function ContactPage() {
  return (
    <main style={{ padding: 24, maxWidth: 880, margin: 0 auto }}>
      <h1 style={{ fontSize: 42, fontWeight: 900, color: '#0A0A0B', marginBottom: 16, letterSpacing: '-0.02em' }}>
        Contact
      </h1>
      <p style={{ fontSize: 18, color: '#666', marginBottom: 32, lineHeight: 1.6 }}>
        Nous contacter.
      </p>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Nous joindre</h2>
        <p style={{ fontSize: 17, color: '#444', lineHeight: 1.8 }}>
          TENΛ Budget est un projet en développement actif. Pour toute question, suggestion
          ou signalement, vous pouvez nous joindre par les moyens suivants.
        </p>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Canaux de communication</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            <strong>Email :</strong> contact@tenabudget.org (adresse de contact générale)
          </li>
          <li>
            <strong>Dépôts de code :</strong> GitHub (code source ouvert, issues et contributions)
          </li>
          <li>
            <strong>Discussions :</strong> Forum communautaire (lien disponible sur le site)
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Ce que nous ne faisons pas</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Nous ne répondons pas aux demandes de "casser" la sécurité ou d'accéder aux données
            d'autres utilisateurs.
          </li>
          <li>
            Nous ne gérons pas de support technique urgent — les délais de réponse dépendent de
            la disponibilité de l'équipe de développement.
          </li>
          <li>
            Nous ne collectons pas de informations personnelles au-delà de ce que vous nous
            fournissez volontairement dans vos messages.
          </li>
        </ul>
      </section>

      <section style={{ margin: 32 0, padding: 24, borderRadius: 16, background: '#fafafa', border: '1px solid #e5e7eb' }}>
        <h2 style={{ fontSize: 30, fontWeight: 700, color: '#0A0A0B', marginBottom: 24 }}>Limitations actuelles</h2>
        <ul style={{ margin: 16 0, paddingLeft: 24, color: '#555', fontSize: 15, lineHeight: 1.8 }}>
          <li>
            Aucun formulaire de contact automatisé n'est déployé sur le site — les adresses
            email sont présentes en texte clair pour éviter les bots.
          </li>
          <li>
            Les demandes sont traitées manuellement par l'équipe de développement dans la mesure
            du possible.
          </li>
          <li>
            Les signalements de bugs de sécurité doivent suivre le processus dédié indiqué sur
            la page sécuritaire du site.
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
