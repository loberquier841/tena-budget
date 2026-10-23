import { MonthlyChart } from '../components/Charts';
import styles from './landing.module.css';

const features = [
  {
    icon: '↕',
    title: 'Revenus et dépenses',
    text: 'Enregistre tes mouvements et retrouve facilement ce qui compte.',
  },
  {
    icon: '▤',
    title: 'Budgets clairs',
    text: 'Fixe des repères par catégorie et vois où tu en es.',
  },
  {
    icon: '◎',
    title: 'Objectifs d’épargne',
    text: 'Donne une cible à tes projets et suis leur progression.',
  },
  {
    icon: '⌁',
    title: 'Prévisions utiles',
    text: 'Appuie-toi sur ton historique pour préparer les mois à venir.',
  },
  {
    icon: '▣',
    title: 'Données sous ton contrôle',
    text: 'Le questionnaire et ton profil restent enregistrés sur ton appareil.',
  },
  {
    icon: '⇄',
    title: 'Import et export',
    text: 'Les formats disponibles dépendent de la version utilisée.',
  },
];

const questions = [
  {
    question: 'Est-ce que je dois connecter ma banque ?',
    answer:
      'Non. La connexion bancaire réelle n’est pas activée. Tu peux découvrir le parcours sans donner d’identifiants bancaires.',
  },
  {
    question: 'Où sont enregistrées mes réponses ?',
    answer:
      'Le questionnaire crée un profil dans le stockage local de ton navigateur. Le parcours ne transmet pas ces réponses à un serveur.',
  },
  {
    question: 'Que se passe-t-il si j’oublie ma phrase secrète ?',
    answer:
      'Elle sert à protéger le coffre local. Sans phrase secrète ni sauvegarde utilisable, les données chiffrées ne peuvent pas être récupérées.',
  },
  {
    question: 'Toutes les fonctions sont-elles déjà disponibles ici ?',
    answer:
      'Non. Ce site présente le projet et permet de découvrir le questionnaire. Certains modules et certaines versions restent en cours de développement.',
  },
];

export default function Home() {
  return (
    <main className={styles.tena}>
      <a className={styles.skipLink} href="#contenu">Aller au contenu</a>
      <div className={styles.wrap}>
        <header className={styles.nav}>
          <a className={styles.brand} href="/" aria-label="TENΛ Budget, accueil">
            <span className={styles.mark} aria-hidden="true">Λ</span>
            <span>TENΛ <b>BUDGET</b></span>
          </a>
          <nav className={styles.navLinks} aria-label="Navigation principale">
            <a href="#fonctionnalites">Fonctionnalités</a>
            <a href="#confidentialite">Confidentialité</a>
            <a className={styles.navCta} href="/onboarding">Découvrir le questionnaire <span aria-hidden="true">↗</span></a>
          </nav>
        </header>

        <section className={styles.hero} id="contenu">
          <div className={styles.heroCopy}>
            <div className={styles.eyebrow}><span aria-hidden="true" /> TON BUDGET, SOUS TON CONTRÔLE</div>
            <h1>Prends tes décisions financières <span>avec plus de clarté.</span></h1>
            <p className={styles.lead}>
              TENΛ Budget t’aide à mieux comprendre tes habitudes et à préparer tes projets.
              Commence par un questionnaire simple, conçu pour rester sur ton appareil.
            </p>
            <div className={styles.actions}>
              <a className={styles.btn + ' ' + styles.primary} href="/onboarding">
                Découvrir mon profil <span aria-hidden="true">→</span>
              </a>
              <a className={styles.btn + ' ' + styles.secondary} href="#fonctionnalites">
                Explorer les fonctionnalités
              </a>
            </div>
            <ul className={styles.trustList} aria-label="Principes du projet">
              <li><span aria-hidden="true">✓</span> Questionnaire local</li>
              <li><span aria-hidden="true">✓</span> Sans banque connectée</li>
              <li><span aria-hidden="true">✓</span> Gratuit pour commencer</li>
            </ul>
          </div>

          <div className={styles.preview} aria-label="Illustration de l’interface, sans données réelles">
            <div className={styles.previewTop}>
              <span className={styles.windowDots} aria-hidden="true"><i /><i /><i /></span>
              <span>APERÇU DE L’INTERFACE</span>
              <span className={styles.previewMark} aria-hidden="true">Λ</span>
            </div>
            <div className={styles.previewHeading}>
              <div><span className={styles.previewLabel}>VUE D’ENSEMBLE</span><h2>Ton mois, en un regard.</h2></div>
              <span className={styles.period}>Ce mois</span>
            </div>
            <div className={styles.previewCards}>
              <div className={styles.previewCard}>
                <span>Revenus</span><strong>À renseigner</strong><small>Quand tu le souhaites</small>
              </div>
              <div className={styles.previewCard}>
                <span>Dépenses</span><strong>À renseigner</strong><small>Pas de données inventées</small>
              </div>
            </div>
            <div className={styles.chartBox}>
              <div className={styles.chartTitle}><span>Ton rythme</span><span>Illustration</span></div>
              <MonthlyChart
                data={[
                  { month: 'Sem. 1', totalCents: 28000 },
                  { month: 'Sem. 2', totalCents: 39000 },
                  { month: 'Sem. 3', totalCents: 33000 },
                  { month: 'Sem. 4', totalCents: 46000 },
                ]}
              />
            </div>
            <div className={styles.previewFooter}><span className={styles.lock} aria-hidden="true">⌑</span><span>Aperçu de design · aucune donnée réelle</span></div>
          </div>
        </section>

        <section className={styles.promise} id="confidentialite">
          <div className={styles.promiseIcon} aria-hidden="true">⌑</div>
          <div>
            <span className={styles.eyebrow}>PENSÉ POUR TA VIE PRIVÉE</span>
            <h2>Ton profil commence et reste chez toi.</h2>
            <p>Le questionnaire enregistre ton profil dans le navigateur. Aucune donnée bancaire n’est demandée et aucune connexion à un serveur n’est nécessaire pour cette étape.</p>
          </div>
          <a href="/onboarding" className={styles.textLink}>Voir comment ça marche <span aria-hidden="true">→</span></a>
        </section>

        <section className={styles.section} id="fonctionnalites">
          <div className={styles.sectionHeader}>
            <div>
              <span className={styles.eyebrow}>LES BONS REPÈRES, SANS COMPLEXITÉ</span>
              <h2>Une base solide pour avancer.</h2>
            </div>
            <p>Le projet rassemble les outils essentiels pour comprendre, organiser et préparer tes finances personnelles.</p>
          </div>
          <div className={styles.grid}>
            {features.map((feature, index) => (
              <article className={styles.card} key={feature.title}>
                <div className={styles.cardTop}>
                  <span className={styles.ico} aria-hidden="true">{feature.icon}</span>
                  <span className={styles.cardIndex}>0{index + 1}</span>
                </div>
                <h3>{feature.title}</h3>
                <p>{feature.text}</p>
              </article>
            ))}
          </div>
          <p className={styles.availability}>
            Les fonctions disponibles varient selon la version. La connexion bancaire réelle et les paiements ne sont pas activés.
          </p>
        </section>

        <section className={styles.section} id="parcours">
          <div className={styles.sectionHeader}>
            <div>
              <span className={styles.eyebrow}>COMMENCE À TON RYTHME</span>
              <h2>Trois étapes, sans inscription distante.</h2>
            </div>
            <p>Le questionnaire adapte le profil et l’expérience à tes besoins, tout en gardant la main sur tes données.</p>
          </div>
          <ol className={styles.steps}>
            <li><span>01</span><div><h3>Protège ton espace</h3><p>Crée une phrase secrète pour ton coffre local.</p></div></li>
            <li><span>02</span><div><h3>Parle de tes besoins</h3><p>Choisis tes priorités et les repères qui t’intéressent.</p></div></li>
            <li><span>03</span><div><h3>Découvre ton profil</h3><p>Retrouve tes réponses et une expérience adaptée.</p></div></li>
          </ol>
        </section>

        <section className={styles.faq} id="questions">
          <div className={styles.faqIntro}>
            <span className={styles.eyebrow}>EN TOUTE TRANSPARENCE</span>
            <h2>Quelques réponses utiles.</h2>
            <p>La confiance commence par des informations claires sur ce qui est disponible et sur la façon dont tes données sont utilisées.</p>
          </div>
          <div className={styles.questions}>
            {questions.map((item) => (
              <details className={styles.question} key={item.question}>
                <summary>{item.question}<span aria-hidden="true">+</span></summary>
                <p>{item.answer}</p>
              </details>
            ))}
          </div>
        </section>

        <section className={styles.finalCta}>
          <div>
            <span className={styles.eyebrow}>FAIS LE PREMIER PAS</span>
            <h2>Un budget plus clair commence par toi.</h2>
            <p>Découvre le questionnaire et décide ensuite de la suite.</p>
          </div>
          <a className={styles.btn + ' ' + styles.primary} href="/onboarding">
            Commencer gratuitement <span aria-hidden="true">→</span>
          </a>
        </section>

        <footer className={styles.footer}>
          <a className={styles.brand} href="/" aria-label="TENΛ Budget, accueil">
            <span className={styles.mark} aria-hidden="true">Λ</span>
            <span>TENΛ <b>BUDGET</b></span>
          </a>
          <span>Finance personnelle · Local-first</span>
          <nav aria-label="Liens de pied de page">
            <a href="#fonctionnalites">Fonctionnalités</a>
            <a href="#confidentialite">Confidentialité</a>
            <a href="#questions">Questions</a>
          </nav>
          <span className={styles.copyright}>© {new Date().getFullYear()} TENΛ Budget</span>
        </footer>
      </div>
    </main>
  );
}
