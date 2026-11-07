import Link from 'next/link';
import styles from './landing.module.css';

export default function NotFound() {
  return (
    <main className={styles.tena}>
      <div className={styles.wrap} style={{ padding: '96px 0', maxWidth: 720 }}>
        <div className={styles.eyebrow}><span aria-hidden="true" /> PAGE INTROUVABLE</div>
        <h1 style={{ marginTop: 16 }}>Cette page n’existe pas.</h1>
        <p className={styles.lead}>Le lien est peut-être incorrect, ou la page a été déplacée. Aucune donnée n’est requise pour revenir à l’accueil.</p>
        <div className={styles.actions} style={{ marginTop: 24 }}>
          <Link className={`${styles.btn} ${styles.primary}`} href="/">Retour à l’accueil</Link>
          <Link className={`${styles.btn} ${styles.secondary}`} href="/download">Téléchargements</Link>
        </div>
      </div>
    </main>
  );
}
