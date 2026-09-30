import React, { useEffect, useMemo, useState } from 'react'
import { getLocalTransactions, saveLocalTransaction } from '@tena/core/src/sync/dexie'

type Page =
  | 'Accueil' | 'Transactions' | 'Budget' | 'Objectifs' | 'Prévisions'
  | 'IA TENΛ' | 'Rapports' | 'Documents' | 'Notifications' | 'Comparateur'
  | 'Famille' | 'Entreprise' | 'Autopilot' | 'Paramètres'

type Tx = {
  id: string
  label: string
  amountCents: number
  bookingDate: Date
  category?: string
}

const pages: { name: Page; icon: string; group?: string }[] = [
  { name: 'Accueil', icon: '⌂' },
  { name: 'Transactions', icon: '↕' },
  { name: 'Budget', icon: '◫' },
  { name: 'Objectifs', icon: '◎' },
  { name: 'Prévisions', icon: '⌁' },
  { name: 'IA TENΛ', icon: '✦' },
  { name: 'Rapports', icon: '▤', group: 'Outils' },
  { name: 'Documents', icon: '□', group: 'Outils' },
  { name: 'Notifications', icon: '♢', group: 'Outils' },
  { name: 'Comparateur', icon: '⌕', group: 'Outils' },
  { name: 'Famille', icon: '♧', group: 'Organisation' },
  { name: 'Entreprise', icon: '▥', group: 'Organisation' },
  { name: 'Autopilot', icon: '⚡', group: 'Organisation' },
  { name: 'Paramètres', icon: '⚙', group: 'Système' },
]

const money = (cents: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(cents / 100)

const dateText = (d: Date) =>
  new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short' }).format(d)

function Card({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <div className={`card ${className}`}>{children}</div>
}

function App() {
  const [page, setPage] = useState<Page>('Accueil')
  const [transactions, setTransactions] = useState<Tx[]>([])
  const [search, setSearch] = useState('')
  const [showAdd, setShowAdd] = useState(false)
  const [toast, setToast] = useState('')
  const [dark, setDark] = useState(true)

  const [label, setLabel] = useState('')
  const [amount, setAmount] = useState('')
  const [category, setCategory] = useState('Alimentation')

  const [budgets, setBudgets] = useState([
    { name: 'Alimentation', limit: 45000, spent: 28650 },
    { name: 'Transport', limit: 18000, spent: 9200 },
    { name: 'Loisirs', limit: 15000, spent: 11750 },
    { name: 'Abonnements', limit: 10000, spent: 6900 },
  ])

  const [goals, setGoals] = useState([
    { name: 'Épargne de sécurité', current: 125000, target: 300000 },
    { name: 'Projet personnel', current: 72000, target: 150000 },
  ])

  useEffect(() => {
    getLocalTransactions('family-demo')
      .then(items => {
        setTransactions(items.map(t => ({
          id: t.id,
          label: t.label,
          amountCents: t.amountCents,
          bookingDate: new Date(t.bookingDate),
          category: t.categoryId,
        })))
      })
      .catch(() => {})
  }, [])

  const totalIncome = useMemo(
    () => transactions.filter(t => t.amountCents > 0).reduce((a, t) => a + t.amountCents, 0),
    [transactions]
  )

  const totalExpenses = useMemo(
    () => Math.abs(transactions.filter(t => t.amountCents < 0).reduce((a, t) => a + t.amountCents, 0)),
    [transactions]
  )

  const balance = totalIncome - totalExpenses + 182450

  const filtered = transactions.filter(t =>
    t.label.toLowerCase().includes(search.toLowerCase())
  )

  async function addTransaction() {
    const euros = Number(amount.replace(',', '.'))
    if (!label.trim() || !Number.isFinite(euros) || euros === 0) {
      setToast('Renseigne un libellé et un montant valide.')
      return
    }

    const tx: Tx = {
      id: `tx_${Date.now()}`,
      label: label.trim(),
      amountCents: Math.round(euros * 100),
      bookingDate: new Date(),
      category,
    }

    try {
      await saveLocalTransaction({
        id: tx.id,
        familyId: 'family-demo',
        amountCents: tx.amountCents,
        bookingDate: tx.bookingDate,
        label: tx.label,
        categoryId: tx.category,
        isDeleted: false,
        syncStatus: 'pending',
        updatedAt: new Date(),
      })
    } catch {}

    setTransactions(current => [tx, ...current])
    setLabel('')
    setAmount('')
    setShowAdd(false)
    setToast('Transaction enregistrée localement.')
    setTimeout(() => setToast(''), 2500)
  }

  function renderHome() {
    return <>
      <div className="hero">
        <div>
          <div className="eyebrow">TENΛ BUDGET</div>
          <h1>Bonjour 👋</h1>
          <p>Voici la situation de ton budget aujourd'hui.</p>
        </div>
        <button className="primary" onClick={() => setShowAdd(true)}>＋ Transaction</button>
      </div>

      <div className="stats">
        <Card><span>Solde</span><strong>{money(balance)}</strong><small>Disponible</small></Card>
        <Card><span>Revenus</span><strong>{money(totalIncome)}</strong><small>Ce mois</small></Card>
        <Card><span>Dépenses</span><strong>{money(totalExpenses)}</strong><small>Ce mois</small></Card>
        <Card><span>Transactions</span><strong>{transactions.length}</strong><small>Enregistrées localement</small></Card>
      </div>

      <div className="grid2">
        <Card>
          <div className="cardHead"><h2>Évolution</h2><button className="ghost">Ce mois</button></div>
          <div className="chart">
            {[42,58,48,70,62,78,67,84,73,91,80,88].map((v,i) =>
              <div key={i} className="bar" style={{height:`${v}%`}} />
            )}
          </div>
          <div className="chartLabels"><span>Sem. 1</span><span>Sem. 2</span><span>Sem. 3</span><span>Sem. 4</span></div>
        </Card>

        <Card>
          <div className="cardHead"><h2>Objectifs</h2><button className="ghost" onClick={() => setPage('Objectifs')}>Voir tout</button></div>
          {goals.map(g => {
            const p = Math.min(100, Math.round(g.current / g.target * 100))
            return <div className="goal" key={g.name}>
              <div><b>{g.name}</b><span>{money(g.current)} / {money(g.target)}</span></div>
              <div className="progress"><i style={{width:`${p}%`}} /></div>
              <small>{p}%</small>
            </div>
          })}
        </Card>
      </div>

      <div className="grid2">
        <Card>
          <div className="cardHead"><h2>Dernières transactions</h2><button className="ghost" onClick={() => setPage('Transactions')}>Tout voir</button></div>
          {transactions.length === 0
            ? <Empty text="Aucune transaction pour le moment." />
            : transactions.slice(0,5).map(t => <TransactionRow key={t.id} tx={t} />)
          }
        </Card>

        <Card className="aiCard">
          <div className="aiIcon">✦</div>
          <div className="eyebrow">TENΛ IA</div>
          <h2>Ton assistant financier</h2>
          <p>Analyse ton budget, détecte les tendances et propose des pistes. Aucune action financière réelle n'est effectuée automatiquement.</p>
          <button className="primary" onClick={() => setPage('IA TENΛ')}>Ouvrir TENΛ IA</button>
        </Card>
      </div>
    </>
  }

  function renderTransactions() {
    return <Module title="Transactions" subtitle="Toutes tes opérations, stockées localement." action={<button className="primary" onClick={() => setShowAdd(true)}>＋ Ajouter</button>}>
      <div className="toolbar"><input placeholder="⌕ Rechercher une transaction..." value={search} onChange={e => setSearch(e.target.value)} /><select><option>Toutes les catégories</option><option>Alimentation</option><option>Transport</option><option>Loisirs</option></select><button className="ghost">Exporter</button></div>
      <Card>
        {filtered.length === 0 ? <Empty text="Aucune transaction trouvée." /> : filtered.map(t => <TransactionRow key={t.id} tx={t} />)}
      </Card>
    </Module>
  }

  function renderBudget() {
    return <Module title="Budget" subtitle="Contrôle les limites et tes dépenses par catégorie." action={<button className="primary">＋ Nouveau budget</button>}>
      <div className="budgetGrid">
        {budgets.map(b => {
          const p = Math.min(100, Math.round(b.spent / b.limit * 100))
          return <Card key={b.name}><div className="budgetTitle"><b>{b.name}</b><span>{p}%</span></div><div className="progress"><i style={{width:`${p}%`}} /></div><div className="budgetNumbers"><strong>{money(b.spent)}</strong><span>sur {money(b.limit)}</span></div><small>{money(Math.max(0,b.limit-b.spent))} restant</small></Card>
        })}
      </div>
      <Card><h2>Analyse du budget</h2><p>Les dépenses sont regroupées localement par catégorie. Les limites peuvent être modifiées selon les permissions définies dans TENΛ Core.</p></Card>
    </Module>
  }

  function renderGoals() {
    return <Module title="Objectifs" subtitle="Construis tes projets et ton épargne." action={<button className="primary">＋ Nouvel objectif</button>}>
      <div className="budgetGrid">{goals.map((g,i) => {
        const p = Math.min(100, Math.round(g.current/g.target*100))
        return <Card key={g.name}><div className="goalBig"><span>◎</span><div><b>{g.name}</b><small>{money(g.target)} objectif</small></div></div><div className="progress"><i style={{width:`${p}%`}} /></div><div className="budgetNumbers"><strong>{money(g.current)}</strong><span>{p}%</span></div><button className="ghost" onClick={() => setGoals(x => x.map((a,n) => n===i ? {...a,current:Math.min(a.target,a.current+2500)} : a))}>＋ Ajouter 25 €</button></Card>
      })}</div>
    </Module>
  }

  function renderForecast() {
    const monthly = Math.max(1, totalExpenses)
    return <Module title="Prévisions" subtitle="Estimations calculées à partir des données disponibles.">
      <div className="stats"><Card><span>Dépenses observées</span><strong>{money(monthly)}</strong><small>Période actuelle</small></Card><Card><span>Projection 30 jours</span><strong>{money(monthly)}</strong><small>Estimation</small></Card><Card><span>Projection annuelle</span><strong>{money(monthly*12)}</strong><small>Si tendance identique</small></Card></div>
      <Card><h2>Scénarios</h2><div className="scenario"><b>Normal</b><span>Maintien du rythme actuel</span><strong>{money(balance-monthly)}</strong></div><div className="scenario"><b>Économie</b><span>-10% de dépenses</span><strong>{money(balance-monthly*.9)}</strong></div><div className="scenario"><b>Prudent</b><span>+10% de dépenses</span><strong>{money(balance-monthly*1.1)}</strong></div></Card>
    </Module>
  }

  function renderAI() {
    return <Module title="IA TENΛ" subtitle="Analyse locale et assistance décisionnelle.">
      <Card className="chat"><div className="aiBubble"><b>✦ TENΛ</b><p>Je peux analyser tes transactions, ton budget, tes objectifs et tes prévisions.</p></div><div className="suggestions"><button onClick={() => setToast('Analyse : surveille surtout les catégories qui dépassent leur budget.')}>Analyser mon budget</button><button onClick={() => setToast('Simulation créée : réduction de 10% des dépenses.')}>Créer une simulation</button><button onClick={() => setToast('Aucune anomalie importante détectée dans les données actuelles.')}>Chercher des anomalies</button></div><div className="chatInput"><input placeholder="Demander quelque chose à TENΛ..." /><button className="primary">Envoyer</button></div></Card>
    </Module>
  }

  function renderReports() {
    return <Module title="Rapports" subtitle="Synthèses et analyses exportables.">
      <div className="budgetGrid">{['Rapport mensuel','Rapport annuel','Dépenses par catégorie','Évolution du patrimoine'].map(x => <Card key={x}><div className="reportIcon">▤</div><h2>{x}</h2><p>Générer une synthèse à partir des données locales.</p><button className="ghost" onClick={() => setToast(`${x} préparé.`)}>Générer</button></Card>)}</div>
    </Module>
  }

  function renderDocuments() {
    return <Module title="Documents" subtitle="Relevés, justificatifs et fichiers associés.">
      <Card className="drop"><div>□</div><h2>Importer un document</h2><p>PDF, CSV, XLSX et autres formats pourront être analysés par TENΛ.</p><button className="primary" onClick={() => setToast('Sélection de fichier disponible dans la prochaine couche d’import.')}>Importer</button></Card>
    </Module>
  }

  function renderNotifications() {
    return <Module title="Notifications" subtitle="Alertes, rappels et événements TENΛ.">
      {['Budget Alimentation proche de sa limite','Objectif Épargne : progression enregistrée','Rapport mensuel disponible'].map((x,i) => <Card className="notice" key={x}><span>{i===0?'!':i===1?'◎':'▤'}</span><div><b>{x}</b><p>{i===0?'Il reste moins de 25% du budget.':'Aujourd’hui'}</p></div></Card>)}
    </Module>
  }

  function renderComparator() {
    return <Module title="Comparateur" subtitle="Compare les prix avant de prendre une décision.">
      <Card><div className="toolbar"><input placeholder="⌕ Rechercher un produit..." /><button className="primary" onClick={() => setToast('Recherche locale prête. Les sources externes seront branchées ensuite.')}>Comparer</button></div><Empty text="L'intégration des sources de prix sera connectée ici." /></Card>
    </Module>
  }

  function renderFamily() {
    return <Module title="Famille" subtitle="Gestion des membres, budgets et permissions.">
      <Card><div className="member"><div className="avatar">O</div><div><b>Propriétaire</b><small>Accès complet selon les permissions TENΛ Core</small></div><span className="pill">OWNER</span></div><div className="member"><div className="avatar">M</div><div><b>Membre familial</b><small>Accès configurable</small></div><span className="pill">MEMBER</span></div><button className="primary">＋ Ajouter un membre</button></Card>
    </Module>
  }

  function renderEnterprise() {
    return <Module title="Entreprise" subtitle="Espace financier professionnel.">
      <div className="stats"><Card><span>Budget</span><strong>—</strong><small>À configurer</small></Card><Card><span>Collaborateurs</span><strong>—</strong><small>À configurer</small></Card><Card><span>Rapports</span><strong>—</strong><small>À configurer</small></Card></div>
      <Card><h2>Organisation</h2><p>Les espaces entreprise, rôles, équipes et rapports seront isolés des données personnelles.</p></Card>
    </Module>
  }

  function renderAutopilot() {
    return <Module title="Autopilot" subtitle="TENΛ propose. Les permissions contrôlent. Tu valides l'action.">
      <Card className="autopilot"><div className="aiIcon">⚡</div><h2>Mode assisté</h2><p>Aucune dépense, aucun achat et aucune opération financière réelle ne sera exécutée automatiquement.</p><div className="steps"><span>1. IA propose</span><span>→</span><span>2. Permissions</span><span>→</span><span>3. Validation</span></div><button className="primary" onClick={() => setToast('Autopilot activé en mode proposition.')}>Activer le mode proposition</button></Card>
    </Module>
  }

  function renderSettings() {
    return <Module title="Paramètres" subtitle="Contrôle ton application et tes données.">
      <Card><Setting title="Mode sombre" desc="Interface sombre de TENΛ Budget." control={<input type="checkbox" checked={dark} onChange={e=>setDark(e.target.checked)} />} /><Setting title="Données locales" desc="Les données principales restent sur cet appareil." control={<span className="pill">LOCAL</span>} /><Setting title="Validation des actions sensibles" desc="Confirmation avant les actions importantes." control={<span className="pill">ACTIF</span>} /><Setting title="Version Core" desc="Moteur métier TENΛ." control={<span className="pill">1.1.0</span>} /></Card>
    </Module>
  }

  function content() {
    switch(page) {
      case 'Accueil': return renderHome()
      case 'Transactions': return renderTransactions()
      case 'Budget': return renderBudget()
      case 'Objectifs': return renderGoals()
      case 'Prévisions': return renderForecast()
      case 'IA TENΛ': return renderAI()
      case 'Rapports': return renderReports()
      case 'Documents': return renderDocuments()
      case 'Notifications': return renderNotifications()
      case 'Comparateur': return renderComparator()
      case 'Famille': return renderFamily()
      case 'Entreprise': return renderEnterprise()
      case 'Autopilot': return renderAutopilot()
      case 'Paramètres': return renderSettings()
    }
  }

  return <div className={dark ? 'app dark' : 'app'}>
    <aside className="sidebar">
      <div className="brand"><div className="logo">Λ</div><div><b>TENΛ</b><small>Budget</small></div></div>
      <div className="workspace">PERSONNEL <span>⌄</span></div>
      <nav>{pages.map(p => <React.Fragment key={p.name}>{p.group && <div className="navGroup">{p.group}</div>}<button className={page===p.name?'active':''} onClick={()=>setPage(p.name)}><i>{p.icon}</i>{p.name}</button></React.Fragment>)}</nav>
      <div className="offline"><span>●</span><div><b>Hors ligne</b><small>Données locales</small></div></div>
    </aside>

    <main>
      <header><div className="breadcrumb">TENΛ Budget <span>/</span> {page}</div><div className="topActions"><input className="globalSearch" placeholder="⌕ Rechercher..." value={search} onChange={e=>setSearch(e.target.value)} /><button className="iconBtn" onClick={()=>setPage('Notifications')}>♢</button><button className="avatar">L</button></div></header>
      <section className="content">{content()}</section>
    </main>

    {showAdd && <div className="modalBack" onClick={()=>setShowAdd(false)}><div className="modal" onClick={e=>e.stopPropagation()}><div className="cardHead"><h2>Nouvelle transaction</h2><button className="iconBtn" onClick={()=>setShowAdd(false)}>×</button></div><label>Libellé<input value={label} onChange={e=>setLabel(e.target.value)} placeholder="Ex. Courses" /></label><label>Montant (€)<input value={amount} onChange={e=>setAmount(e.target.value)} placeholder="-42,50" /></label><label>Catégorie<select value={category} onChange={e=>setCategory(e.target.value)}><option>Alimentation</option><option>Transport</option><option>Loisirs</option><option>Abonnements</option><option>Autre</option></select></label><button className="primary full" onClick={addTransaction}>Enregistrer localement</button></div></div>}

    {toast && <div className="toast">{toast}</div>}

    <style>{styles}</style>
  </div>
}

function Module({title,subtitle,action,children}:{title:string;subtitle:string;action?:React.ReactNode;children:React.ReactNode}) {
  return <><div className="moduleHead"><div><div className="eyebrow">TENΛ BUDGET</div><h1>{title}</h1><p>{subtitle}</p></div>{action}</div>{children}</>
}

function TransactionRow({tx}:{tx:Tx}) {
  const positive = tx.amountCents > 0
  return <div className="tx"><div className="txIcon">{positive?'↗':'↘'}</div><div className="txMain"><b>{tx.label}</b><small>{tx.category || 'Non catégorisé'} · {dateText(tx.bookingDate)}</small></div><strong className={positive?'positive':'negative'}>{positive?'+':''}{money(tx.amountCents)}</strong></div>
}

function Empty({text}:{text:string}) { return <div className="empty"><span>□</span><p>{text}</p></div> }
function Setting({title,desc,control}:{title:string;desc:string;control:React.ReactNode}) { return <div className="setting"><div><b>{title}</b><p>{desc}</p></div>{control}</div> }

const styles = `
*{box-sizing:border-box}body{margin:0;font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#080b12;color:#eef2f7}button,input,select{font:inherit}button{cursor:pointer}.app{min-height:100vh;background:#f4f6f8;color:#18202c;display:flex}.app.dark{background:#090d14;color:#eef2f7}.sidebar{width:248px;min-height:100vh;background:#0d121b;border-right:1px solid #202936;padding:22px 14px;position:fixed;left:0;top:0;bottom:0;overflow:auto}.brand{display:flex;align-items:center;gap:11px;padding:0 10px 24px}.logo{width:38px;height:38px;border-radius:11px;display:grid;place-items:center;background:#fff;color:#080b12;font-size:23px;font-weight:900}.brand b{display:block;font-size:18px}.brand small{color:#8994a5}.workspace{font-size:10px;letter-spacing:1.5px;color:#778397;padding:13px 12px;border-top:1px solid #202936;border-bottom:1px solid #202936;margin-bottom:10px}.workspace span{float:right}nav button{display:flex;width:100%;border:0;background:transparent;color:#9da8b9;text-align:left;padding:10px 12px;border-radius:9px;align-items:center;gap:11px;margin:2px 0}nav button:hover{background:#171e29;color:#fff}nav button.active{background:#fff;color:#0a0e15;font-weight:700}.dark nav button.active{background:#eef2f7}.navGroup{font-size:9px;text-transform:uppercase;letter-spacing:1.5px;color:#596679;margin:18px 12px 6px}.offline{position:absolute;bottom:18px;left:14px;right:14px;background:#121a25;border:1px solid #263141;border-radius:10px;padding:10px;display:flex;gap:9px}.offline span{color:#52d68a}.offline b,.offline small{display:block}.offline small{color:#778397;font-size:11px;margin-top:2px}main{margin-left:248px;width:calc(100% - 248px);min-width:0}header{height:68px;border-bottom:1px solid #dce1e8;background:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 30px;position:sticky;top:0;z-index:5}.dark header{background:#0d121b;border-color:#202936}.breadcrumb{font-weight:700}.breadcrumb span{color:#8994a5;margin:0 8px}.topActions{display:flex;align-items:center;gap:10px}.globalSearch{width:210px;background:#f3f5f7;border:1px solid #e0e4e9;border-radius:8px;padding:9px 12px;outline:none}.dark .globalSearch{background:#141b25;border-color:#293444;color:#fff}.iconBtn,.avatar,.ghost{border:1px solid #dfe4ea;background:transparent;border-radius:8px;padding:8px 11px}.dark .iconBtn,.dark .ghost{border-color:#2a3544;color:#dce3ec}.avatar{width:35px;height:35px;padding:0;border-radius:50%;background:#202938;color:#fff;border:0}.content{padding:32px;max-width:1500px;margin:auto}.hero,.moduleHead{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:28px}.hero h1,.moduleHead h1{font-size:31px;margin:5px 0}.hero p,.moduleHead p{color:#7d8899;margin:0}.eyebrow{font-size:10px;letter-spacing:2px;font-weight:800;color:#718096}.primary{border:0;border-radius:8px;background:#fff;color:#080b12;padding:10px 15px;font-weight:750}.dark .primary{background:#f2f5f8}.full{width:100%;margin-top:10px}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:16px}.card{background:#fff;border:1px solid #dfe4ea;border-radius:12px;padding:20px;margin-bottom:16px}.dark .card{background:#101620;border-color:#222d3b}.stats .card span,.stats .card small{display:block;color:#7d8899}.stats .card strong{display:block;font-size:26px;margin:10px 0 5px}.grid2{display:grid;grid-template-columns:1.35fr 1fr;gap:16px}.grid2>.card{margin:0}.cardHead{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}.card h2{font-size:16px;margin:0}.chart{height:190px;display:flex;align-items:end;gap:10px;padding:20px 8px 0}.bar{flex:1;border-radius:5px 5px 2px 2px;background:#758196;min-height:12px}.chartLabels{display:flex;justify-content:space-between;color:#788496;font-size:10px}.goal{margin:17px 0}.goal>div:first-child{display:flex;justify-content:space-between}.goal span,.goal small{color:#7c8798;font-size:12px}.progress{height:7px;background:#e4e8ed;border-radius:10px;overflow:hidden;margin:8px 0}.dark .progress{background:#222c39}.progress i{display:block;height:100%;background:#778397;border-radius:10px}.aiCard{background:linear-gradient(145deg,#111925,#171f2c)!important;color:#fff}.aiCard p{color:#aab4c2;line-height:1.6}.aiIcon{font-size:28px;margin-bottom:12px}.tx{display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #e4e8ed}.dark .tx{border-color:#242d3a}.tx:last-child{border:0}.txIcon{width:34px;height:34px;border-radius:9px;background:#edf0f3;display:grid;place-items:center;color:#566274}.dark .txIcon{background:#1c2531}.txMain{flex:1}.txMain b,.txMain small{display:block}.txMain small{color:#7d8899;font-size:11px;margin-top:3px}.positive{color:#429a68}.negative{color:#c75e64}.toolbar{display:flex;gap:10px;margin-bottom:16px}.toolbar input,.toolbar select{flex:1;padding:10px 12px;border:1px solid #dfe4ea;border-radius:8px;background:#fff;outline:none}.dark .toolbar input,.dark .toolbar select{background:#101620;border-color:#293444;color:#fff}.budgetGrid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}.budgetGrid>.card{margin:0}.budgetTitle,.budgetNumbers{display:flex;justify-content:space-between;align-items:center}.budgetTitle span{color:#7c8798}.budgetNumbers{margin-top:10px}.budgetNumbers span{color:#7c8798;font-size:12px}.goalBig{display:flex;gap:12px;align-items:center;margin-bottom:20px}.goalBig>span{font-size:30px}.goalBig b,.goalBig small{display:block}.goalBig small{color:#7d8899;margin-top:3px}.scenario,.member,.notice,.setting{display:flex;align-items:center;gap:15px;padding:16px 0;border-bottom:1px solid #e4e8ed}.dark .scenario,.dark .member,.dark .notice,.dark .setting{border-color:#252e3a}.scenario span,.scenario strong{margin-left:auto}.scenario span{color:#7d8899}.chat{min-height:500px}.aiBubble{max-width:650px;background:#161e2b;border:1px solid #293545;border-radius:12px;padding:16px}.aiBubble p{color:#b0bac8}.suggestions{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}.suggestions button{background:transparent;color:inherit;border:1px solid #344052;border-radius:20px;padding:9px 13px}.chatInput{display:flex;gap:10px;margin-top:250px}.chatInput input{flex:1;padding:12px;border:1px solid #303b4c;border-radius:8px;background:#0d131d;color:#fff}.reportIcon{font-size:25px}.drop{text-align:center;padding:60px}.drop>div{font-size:42px}.notice>span{font-size:22px}.notice p{margin:4px 0 0;color:#7d8899}.member .avatar{display:grid;place-items:center}.member div:nth-child(2){flex:1}.member small{display:block;color:#7d8899;margin-top:3px}.pill{font-size:9px;letter-spacing:1px;padding:5px 8px;border-radius:20px;background:#e8ebef;color:#5d6878}.dark .pill{background:#202a37;color:#b9c3d1}.autopilot{text-align:center;padding:50px}.steps{display:flex;justify-content:center;gap:12px;flex-wrap:wrap;margin:25px}.steps span{padding:10px 14px;background:#182130;border-radius:8px}.setting>div{flex:1}.setting p{margin:5px 0 0;color:#7d8899}.empty{text-align:center;padding:45px;color:#7d8899}.empty span{font-size:30px}.modalBack{position:fixed;inset:0;background:#0009;display:grid;place-items:center;z-index:20}.modal{width:min(450px,90vw);background:#fff;color:#18202c;border-radius:14px;padding:22px;box-shadow:0 20px 80px #0008}.dark .modal{background:#111823;color:#fff}.modal label{display:block;font-size:12px;font-weight:700;margin:15px 0}.modal input,.modal select{display:block;width:100%;margin-top:6px;padding:11px;border:1px solid #dce1e8;border-radius:8px;background:transparent;color:inherit}.toast{position:fixed;right:25px;bottom:25px;background:#151d29;color:#fff;border:1px solid #344052;border-radius:10px;padding:13px 17px;z-index:30;box-shadow:0 10px 30px #0005}@media(max-width:900px){.sidebar{width:76px}.brand div:not(.logo),.workspace,nav button:not(.active)::after,nav button{font-size:0}.brand{padding:0 5px 24px}.logo{margin:auto}.sidebar nav button{justify-content:center;font-size:20px}.sidebar nav button i{font-size:20px}main{margin-left:76px;width:calc(100% - 76px)}.stats{grid-template-columns:repeat(2,1fr)}.grid2{grid-template-columns:1fr}.content{padding:20px}.globalSearch{display:none}}@media(max-width:600px){.budgetGrid,.stats{grid-template-columns:1fr}.moduleHead,.hero{align-items:flex-start;gap:15px;flex-direction:column}header{padding:0 15px}.content{padding:15px}.topActions .iconBtn{display:none}}
`
