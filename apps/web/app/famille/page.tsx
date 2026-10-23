import Link from 'next/link';

export default function FamillePage() {
  return (
    <main style={{ maxWidth: 760, margin: '0 auto', padding: '48px 20px', color: '#f5f5f7' }}>
      <p style={{ color: '#e8cc6a', fontSize: 12, letterSpacing: '.12em' }}>TENΛ BUDGET</p>
      <h1>Espace famille</h1>
      <p style={{ color: '#a0a0ab', lineHeight: 1.7 }}>
        Le partage familial, les invitations et la gestion des rôles ne sont pas encore disponibles dans cette version.
        Les données personnelles restent gérées sur cet appareil.
      </p>
      <Link href="/dashboard" style={{ color: '#e8cc6a' }}>Retour au tableau de bord</Link>
    </main>
  );
}
