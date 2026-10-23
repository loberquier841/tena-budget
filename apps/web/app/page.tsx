const styles = `
  *{box-sizing:border-box}.tena{background:#08090d;color:#f7f5ef;min-height:calc(100vh - 64px);overflow:hidden}.wrap{width:min(1120px,calc(100% - 36px));margin:auto}
  .nav{display:flex;justify-content:space-between;align-items:center;padding:24px 0;border-bottom:1px solid #25252d}.brand{display:flex;align-items:center;gap:11px;font-weight:850;letter-spacing:.05em}
  .mark{display:grid;place-items:center;width:38px;height:38px;border-radius:12px;background:linear-gradient(135deg,#f6d982,#b58b2a);color:#101014;font-size:21px}
  .pill{border:1px solid #51452a;border-radius:99px;color:#f0d58d;padding:8px 12px;font-size:11px;letter-spacing:.06em}.hero{display:grid;grid-template-columns:1.1fr .9fr;gap:44px;align-items:center;padding:76px 0}
  .eyebrow{color:#e5c777;font-size:11px;font-weight:800;letter-spacing:.17em;text-transform:uppercase}.hero h1{font-size:clamp(44px,6vw,72px);line-height:1.01;letter-spacing:-.055em;margin:18px 0}.hero h1 span{color:#e6c777}
  .lead{max-width:590px;color:#b9bac3;font-size:18px;line-height:1.75}.actions{display:flex;gap:12px;flex-wrap:wrap;margin-top:27px}.btn{display:inline-flex;align-items:center;justify-content:center;padding:13px 18px;border-radius:12px;text-decoration:none;font-weight:750;font-size:14px}.primary{background:#e7c979;color:#111216}.secondary{border:1px solid #34343e;color:#f5f2e9}
  .note{color:#858793;font-size:12px;line-height:1.65;margin-top:17px}.preview{border:1px solid #39301c;border-radius:24px;padding:22px;background:linear-gradient(145deg,#171820,#101116);box-shadow:0 24px 90px #0006}
  .ptop{display:flex;justify-content:space-between;color:#c6c6ce;font-size:11px}.ptitle{font-size:20px;font-weight:800;margin-top:24px}.balance{font-size:28px;font-weight:850;margin:8px 0 20px}.balance small{font-size:11px;color:#aaaab4;font-weight:500}
  .bars{height:110px;display:flex;align-items:end;gap:9px;padding:8px 0 15px;border-bottom:1px solid #2b2c34}.bar{flex:1;border-radius:6px 6px 2px 2px;background:linear-gradient(180deg,#e8ce84,#9c762b)}
  .minis{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-top:16px}.mini{padding:13px;background:#202129;border-radius:12px}.mini small{display:block;color:#aaaab4;font-size:11px}.mini strong{display:block;margin-top:7px}
  .section{padding:62px 0;border-top:1px solid #25252d}.section h2{font-size:clamp(28px,4vw,42px);letter-spacing:-.035em;margin:10px 0 12px}.intro{max-width:670px;color:#aaaab4;line-height:1.75}
  .grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px;margin-top:28px}.card{padding:22px;border:1px solid #292a32;border-radius:18px;background:#111218}.ico{display:grid;place-items:center;width:40px;height:40px;border-radius:12px;background:#28251c;color:#e8cb7c;font-size:20px}
  .card h3{margin:17px 0 8px;font-size:16px}.card p{margin:0;color:#a7a8b2;line-height:1.7;font-size:14px}.principles{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:24px}
  .principle{padding:17px;border-left:2px solid #d8b961;background:#121319;color:#d8d8de;font-size:14px;line-height:1.6}.cta{display:flex;align-items:center;justify-content:space-between;gap:24px;padding:28px;border:1px solid #51452a;border-radius:22px;background:linear-gradient(120deg,#191912,#111218)}
  .cta h2{font-size:25px;margin:0 0 8px}.cta p{color:#aaaab4;margin:0;line-height:1.6}.footer{padding:28px 0 36px;color:#7f818d;font-size:12px;display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap;border-top:1px solid #25252d}.footer a{color:#c9c9d0}
  @media(max-width:800px){.hero{grid-template-columns:1fr;gap:30px;padding:54px 0}.grid{grid-template-columns:repeat(2,minmax(0,1fr))}.principles{grid-template-columns:1fr}.cta{align-items:flex-start;flex-direction:column}}
  @media(max-width:520px){.wrap{width:calc(100% - 28px)}.nav{padding:18px 0}.pill{font-size:9px;padding:7px 8px}.grid{grid-template-columns:1fr}.hero h1{font-size:44px}.lead{font-size:16px}.preview{padding:16px}}
`;

export default function Home() {
  return <main className="tena"><style>{styles}</style><div className="wrap">
    <header className="nav"><div className="brand"><span className="mark">Λ</span><span>TENΛ BUDGET</span></div><span className="pill">GRATUIT · LOCAL-FIRST</span></header>
    <section className="hero"><div><div className="eyebrow">Reprends la main sur ton argent</div><h1>Ton budget.<br/><span>Tes choix.</span><br/>Ta liberté.</h1>
      <p className="lead">Une façon plus claire de suivre tes dépenses, préparer tes projets et comprendre où va ton argent — avec une priorité : tes données restent sous ton contrôle.</p>
      <div className="actions"><a className="btn primary" href="/dashboard">Découvrir l’application →</a><a className="btn secondary" href="#fonctionnalites">Voir les fonctionnalités</a></div>
      <p className="note">La gestion financière de base vise un fonctionnement local et hors connexion. Aucune connexion bancaire n’est activée par cette page.</p></div>
      <div className="preview" aria-label="Aperçu illustratif du tableau de bord"><div className="ptop"><span>APERÇU DU TABLEAU DE BORD</span><span>Λ</span></div><div className="ptitle">Vue d’ensemble</div><div className="balance">Maîtrise du budget <small>aperçu visuel</small></div>
      <div className="bars" aria-hidden="true"><span className="bar" style={{height:'36%'}}/><span className="bar" style={{height:'57%'}}/><span className="bar" style={{height:'43%'}}/><span className="bar" style={{height:'76%'}}/><span className="bar" style={{height:'53%'}}/><span className="bar" style={{height:'91%'}}/><span className="bar" style={{height:'66%'}}/></div>
      <div className="minis"><div className="mini"><small>Revenus</small><strong>À suivre</strong></div><div className="mini"><small>Dépenses</small><strong>À maîtriser</strong></div></div><p className="note">Illustration de design — aucune donnée réelle.</p></div></section>
    <section id="fonctionnalites" className="section"><div className="eyebrow">L’essentiel, sans complication</div><h2>Un budget plus simple à comprendre.</h2><p className="intro">TENΛ Budget se construit autour de fonctions utiles au quotidien, sans t’obliger à connecter une banque ni à confier tes données à un service distant pour gérer ton budget de base.</p>
      <div className="grid">
      <article className="card"><div className="ico">↕</div><h3>Transactions</h3><p>Ajoute et classe tes revenus et dépenses, retrouve l’historique et garde le contrôle de tes mouvements.</p></article>
      <article className="card"><div className="ico">▤</div><h3>Budgets par catégorie</h3><p>Fixe des limites pour les postes importants et compare tes prévisions avec tes dépenses.</p></article>
      <article className="card"><div className="ico">◎</div><h3>Objectifs d’épargne</h3><p>Donne une cible à tes projets et suis leur progression au fil du temps.</p></article>
      <article className="card"><div className="ico">⌁</div><h3>Prévisions et rapports</h3><p>Transforme l’historique disponible en repères pour mieux préparer les prochains mois.</p></article>
      <article className="card"><div className="ico">⇄</div><h3>Import et export</h3><p>La disponibilité des outils varie selon la version ; les fonctions en cours ne sont pas présentées comme terminées.</p></article>
      <article className="card"><div className="ico">⌑</div><h3>Hors connexion</h3><p>L’objectif est de gérer ton budget sans dépendre d’un serveur en permanence.</p></article></div></section>
    <section className="section"><div className="eyebrow">Nos principes</div><h2>Gratuit pour gérer ton budget. Conçu pour te respecter.</h2><div className="principles">
      <div className="principle"><strong>Pas de serveur obligatoire</strong><br/>pour le suivi budgétaire local de base.</div><div className="principle"><strong>Pas de banque simulée</strong><br/>les connexions bancaires réelles ne sont pas présentées comme actives.</div><div className="principle"><strong>Pas de promesse inventée</strong><br/>les fonctions en cours de construction sont signalées comme telles.</div></div></section>
    <section className="section"><div className="cta"><div><h2>Prêt à faire le point ?</h2><p>Découvre l’application et ses fonctions disponibles aujourd’hui.</p></div><a className="btn primary" href="/dashboard">Ouvrir TENΛ Budget →</a></div></section>
    <footer className="footer"><span>© {new Date().getFullYear()} TENΛ Budget</span><span>Finance personnelle · Local-first · <a href="#fonctionnalites">Fonctionnalités</a></span></footer>
  </div></main>;
}
