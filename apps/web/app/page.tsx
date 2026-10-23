
import styles from './landing.module.css';

export default function Home() {
  return <main className={styles.tena}><div className={styles.wrap}>
    <header className={styles.nav}><div className={styles.brand}><span className={styles.mark}>Λ</span><span>TENΛ BUDGET</span></div><span className={styles.pill}>GRATUIT · LOCAL-FIRST</span></header>
    <section className={styles.hero}><div><div className={styles.eyebrow}>Reprends la main sur ton argent</div><h1>Ton budget.<br/><span>Tes choix.</span><br/>Ta liberté.</h1>
      <p className={styles.lead}>Une façon plus claire de suivre tes dépenses, préparer tes projets et comprendre où va ton argent — avec une priorité : tes données restent sous ton contrôle.</p>
      <div className={styles.actions}><a className={styles.btn + ' ' + styles.primary} href="/onboarding">Commencer gratuitement →</a><a className={styles.btn + ' ' + styles.secondary} href="#fonctionnalites">Voir les fonctionnalités</a></div>
      <p className={styles.note}>La gestion financière de base vise un fonctionnement local et hors connexion. Aucune connexion bancaire n’est activée par cette page.</p></div>
      <div className={styles.preview} aria-label="Aperçu illustratif du tableau de bord"><div className={styles.ptop}><span>APERÇU DU TABLEAU DE BORD</span><span>Λ</span></div><div className={styles.ptitle}>Vue d’ensemble</div><div className={styles.balance}>Maîtrise du budget <small>aperçu visuel</small></div>
      <div className={styles.bars} aria-hidden="true"><span className={styles.bar} style={{height:'36%'}}/><span className={styles.bar} style={{height:'57%'}}/><span className={styles.bar} style={{height:'43%'}}/><span className={styles.bar} style={{height:'76%'}}/><span className={styles.bar} style={{height:'53%'}}/><span className={styles.bar} style={{height:'91%'}}/><span className={styles.bar} style={{height:'66%'}}/></div>
      <div className={styles.minis}><div className={styles.mini}><small>Revenus</small><strong>À suivre</strong></div><div className={styles.mini}><small>Dépenses</small><strong>À maîtriser</strong></div></div><p className={styles.note}>Illustration de design — aucune donnée réelle.</p></div></section>
    <section id="fonctionnalites" className={styles.section}><div className={styles.eyebrow}>L’essentiel, sans complication</div><h2>Un budget plus simple à comprendre.</h2><p className={styles.intro}>TENΛ Budget se construit autour de fonctions utiles au quotidien, sans t’obliger à connecter une banque ni à confier tes données à un service distant pour gérer ton budget de base.</p>
      <div className={styles.grid}>
      <article className={styles.card}><div className={styles.ico}>↕</div><h3>Transactions</h3><p>Ajoute et classe tes revenus et dépenses, retrouve l’historique et garde le contrôle de tes mouvements.</p></article>
      <article className={styles.card}><div className={styles.ico}>▤</div><h3>Budgets par catégorie</h3><p>Fixe des limites pour les postes importants et compare tes prévisions avec tes dépenses.</p></article>
      <article className={styles.card}><div className={styles.ico}>◎</div><h3>Objectifs d’épargne</h3><p>Donne une cible à tes projets et suis leur progression au fil du temps.</p></article>
      <article className={styles.card}><div className={styles.ico}>⌁</div><h3>Prévisions et rapports</h3><p>Transforme l’historique disponible en repères pour mieux préparer les prochains mois.</p></article>
      <article className={styles.card}><div className={styles.ico}>⇄</div><h3>Import et export</h3><p>La disponibilité des outils varie selon la version ; les fonctions en cours ne sont pas présentées comme terminées.</p></article>
      <article className={styles.card}><div className={styles.ico}>⌑</div><h3>Hors connexion</h3><p>L’objectif est de gérer ton budget sans dépendre d’un serveur en permanence.</p></article></div></section>
    <section className={styles.section}><div className={styles.eyebrow}>Nos principes</div><h2>Gratuit pour gérer ton budget. Conçu pour te respecter.</h2><div className={styles.principles}>
      <div className={styles.principle}><strong>Pas de serveur obligatoire</strong><br/>pour le suivi budgétaire local de base.</div><div className={styles.principle}><strong>Pas de banque simulée</strong><br/>les connexions bancaires réelles ne sont pas présentées comme actives.</div><div className={styles.principle}><strong>Pas de promesse inventée</strong><br/>les fonctions en cours de construction sont signalées comme telles.</div></div></section>
    <section className={styles.section}><div className={styles.cta}><div><h2>Prêt à faire le point ?</h2><p>Découvre l’application et ses fonctions disponibles aujourd’hui.</p></div><a className={styles.btn + ' ' + styles.primary} href="/onboarding">Créer mon espace gratuitement →</a></div></section>
    <footer className={styles.footer}><span>© {new Date().getFullYear()} TENΛ Budget</span><span>Finance personnelle · Local-first · <a href="#fonctionnalites">Fonctionnalités</a></span></footer>
  </div></main>;
}
