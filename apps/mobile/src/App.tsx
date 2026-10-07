import React, { useEffect, useMemo, useRef, useState } from 'react'
import { createLocalVaultAndMigrate, getLocalBudgets, getLocalDeletedTransactions, getLocalOnboardingProgress, getLocalSavingGoals, getLocalTransactions, getLocalUserProfile, getLocalVaultStatus, lockLocalDatabase, restoreLocalTransaction, saveLocalBudget, saveLocalOnboardingProgress, saveLocalSavingGoal, saveLocalTransaction, saveLocalUserProfile, softDeleteLocalTransaction, unlockLocalDatabase, type LocalBudget, type LocalSavingGoal } from '@tena/core/src/sync/dexie'
import { createBudget } from '@tena/core/src/budget/budget'
import { addContribution, createSavingGoal } from '@tena/core/src/budget/savings'
import { createLocalBackup, restoreLocalBackup } from '@tena/core/src/backup/local'
import { decryptBackup, encryptBackup, type EncryptedBackup } from '@tena/core/src/backup/backup'
import { assertCan, type Role } from '@tena/core/src/permissions/permissions'
import { createUserProfile, PRODUCT_CAPABILITIES, recommendForProfile, updateUserProfile, type DashboardCardId, type OnboardingAnswers, type OnboardingProgress, type UserProfile, type UserPriority } from '@tena/core/src/product/profile'

type Page =
  | 'Accueil' | 'Transactions' | 'Budget' | 'Objectifs' | 'Prévisions'
  | 'IA TENΛ' | 'Rapports' | 'Documents' | 'Notifications' | 'Comparateur'
  | 'Sauvegardes' | 'Famille' | 'Entreprise' | 'Autopilot' | 'Mon profil' | 'Paramètres'

type Tx = {
  id: string
  label: string
  amountCents: number
  bookingDate: Date
  category?: string
  personId?: string
  deletedAt?: Date
}

const familyId = 'family-demo'
// L’espace local autonome est créé par son propriétaire. Les permissions TENΛ
// restent vérifiées par le moteur avant toute écriture.
const localRole: Role = 'owner'

const pages: { name: Page; icon: string; group?: string }[] = [
  { name: 'Accueil', icon: '⌂' },
  { name: 'Mon profil', icon: '◎' },
  { name: 'Transactions', icon: '↕' },
  { name: 'Budget', icon: '◫' },
  { name: 'Objectifs', icon: '◎' },
  { name: 'Prévisions', icon: '⌁' },
  { name: 'IA TENΛ', icon: '✦' },
  { name: 'Rapports', icon: '▤', group: 'Outils' },
  { name: 'Documents', icon: '□', group: 'Outils' },
  { name: 'Notifications', icon: '♢', group: 'Outils' },
  { name: 'Comparateur', icon: '⌕', group: 'Outils' },
  { name: 'Sauvegardes', icon: '▣', group: 'Outils' },
  { name: 'Famille', icon: '♧', group: 'Organisation' },
  { name: 'Entreprise', icon: '▥', group: 'Organisation' },
  { name: 'Autopilot', icon: '⚡', group: 'Organisation' },
  { name: 'Paramètres', icon: '⚙', group: 'Système' },
]

const money = (cents: number) =>
  new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(cents / 100)

const dateText = (d: Date) =>
  new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short' }).format(d)

function parseEuroCents(value: string): number | null {
  const normalized = value.replace(/[\s\u00a0\u202f]/g, '').trim()
  const match = normalized.match(/^(-?)(\d+)(?:[,.](\d{1,2}))?$/)
  if (!match) return null
  const cents = Number(match[2]) * 100 + Number((match[3] || '').padEnd(2, '0'))
  if (!Number.isSafeInteger(cents)) return null
  return match[1] ? -cents : cents
}

function Card({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return <div className={`card ${className}`}>{children}</div>
}

function App() {
  const [page, setPage] = useState<Page>('Accueil')
  const [transactions, setTransactions] = useState<Tx[]>([])
  const [deletedTransactions, setDeletedTransactions] = useState<Tx[]>([])
  const [search, setSearch] = useState('')
  const [showAdd, setShowAdd] = useState(false)
  const [toast, setToast] = useState('')
  const [dark, setDark] = useState(false)
  const [dataLoading, setDataLoading] = useState(true)
  const [dataError, setDataError] = useState('')
  const [vaultScreen, setVaultScreen] = useState<'checking' | 'setup' | 'locked' | 'unlocked'>('checking')
  const [vaultHasExistingData, setVaultHasExistingData] = useState(false)
  const [vaultPassphrase, setVaultPassphrase] = useState('')
  const [vaultPassphraseConfirm, setVaultPassphraseConfirm] = useState('')
  const [vaultBackupDownloaded, setVaultBackupDownloaded] = useState(false)
  const [vaultBackupConfirmed, setVaultBackupConfirmed] = useState(false)
  const [vaultBusy, setVaultBusy] = useState(false)
  const [vaultMessage, setVaultMessage] = useState('')
  const [userProfile, setUserProfile] = useState<UserProfile | undefined>()
  const [profileReady, setProfileReady] = useState(false)
  const [profileStep, setProfileStep] = useState(0)
  const [onboardingProgress, setOnboardingProgress] = useState(false)
  const [onboardingStartedAt, setOnboardingStartedAt] = useState(() => new Date().toISOString())
  const progressSaveQueue = useRef<Promise<void>>(Promise.resolve())
  const [profileBusy, setProfileBusy] = useState(false)
  const [profileMessage, setProfileMessage] = useState('')
  const [profileDraft, setProfileDraft] = useState<OnboardingAnswers>({
    householdMode: 'personal', incomePattern: 'regular', budgetExperience: 'starting',
    priorities: ['understand-money'], wantedFeatures: ['transactions', 'budgets', 'savings-goals'], notificationPreference: 'balanced',
  })
  const [dashboardDraft, setDashboardDraft] = useState<DashboardCardId[]>(['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'])
  const [compactDraft, setCompactDraft] = useState(false)
  const [categoryFilter, setCategoryFilter] = useState('')
  const [showTrash, setShowTrash] = useState(false)
  const [showAddBudget, setShowAddBudget] = useState(false)
  const [showAddGoal, setShowAddGoal] = useState(false)
  const [goalName, setGoalName] = useState('')
  const [goalTarget, setGoalTarget] = useState('')
  const [backupPassword, setBackupPassword] = useState('')
  const [restorePassword, setRestorePassword] = useState('')
  const [backupFile, setBackupFile] = useState<File | null>(null)
  const [backupBusy, setBackupBusy] = useState(false)
  const [budgetAmount, setBudgetAmount] = useState('')
  const [budgetCategory, setBudgetCategory] = useState('')
  const [budgetType, setBudgetType] = useState<'annual' | 'monthly'>('monthly')
  const [budgetMonth, setBudgetMonth] = useState(new Date().getMonth() + 1)
  const [budgetYear, setBudgetYear] = useState(new Date().getFullYear())
  const [selectedBudgetYear, setSelectedBudgetYear] = useState(new Date().getFullYear())
  const [selectedBudgetMonth, setSelectedBudgetMonth] = useState(new Date().getMonth() + 1)

  const [label, setLabel] = useState('')
  const [amount, setAmount] = useState('')
  const [category, setCategory] = useState('Alimentation')

  const [budgets, setBudgets] = useState<LocalBudget[]>([])

  const [goals, setGoals] = useState<LocalSavingGoal[]>([])

  async function refreshLocalData() {
    setDataLoading(true)
    try {
      const [items, deletedItems, localBudgets, localGoals] = await Promise.all([getLocalTransactions(familyId), getLocalDeletedTransactions(familyId), getLocalBudgets(familyId), getLocalSavingGoals(familyId)])
      const mapTransaction = (t: (typeof items)[number]): Tx => ({
        id: t.id,
        label: t.label,
        amountCents: t.amountCents,
        bookingDate: new Date(t.bookingDate),
        category: t.categoryId,
        personId: t.personId,
        deletedAt: t.deletedAt ? new Date(t.deletedAt) : undefined,
      })
      setTransactions(items.map(mapTransaction))
      setDeletedTransactions(deletedItems.map(mapTransaction))
      setBudgets(localBudgets)
      setGoals(localGoals)
      setDataError('')
    } catch {
      setDataError('Les données locales n’ont pas pu être chargées.')
    } finally {
      setDataLoading(false)
    }
  }

  useEffect(() => {
    void getLocalVaultStatus().then(status => {
      setVaultHasExistingData(status.hasExistingData)
      setVaultScreen(status.configured ? 'locked' : 'setup')
    }).catch(() => setVaultMessage('Le stockage local ne peut pas être ouvert. Aucune donnée n’a été modifiée.'))
  }, [])

  useEffect(() => {
    if (vaultScreen !== 'unlocked') return
    void refreshLocalData()
    void Promise.all([getLocalVaultStatus(), getLocalUserProfile(), getLocalOnboardingProgress()]).then(([status, profile, progress]) => {
      setUserProfile(profile)
      setProfileDraft(profile?.answers ?? progress?.answers ?? {
        householdMode: 'personal', incomePattern: 'regular', budgetExperience: 'starting',
        priorities: ['understand-money'], wantedFeatures: ['transactions', 'budgets', 'savings-goals'], notificationPreference: 'balanced',
      })
      setDashboardDraft(profile?.dashboard.visibleCards ?? progress?.dashboard.visibleCards ?? ['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'])
      setCompactDraft(profile?.dashboard.compact ?? progress?.dashboard.compact ?? false)
      setProfileStep(profile ? 0 : progress?.currentStep ?? 0)
      setOnboardingStartedAt(progress?.startedAt ?? new Date().toISOString())
      setOnboardingProgress(Boolean(progress))
      setProfileReady(true)
      if (!profile && (!status.hasExistingData || progress)) setPage('Mon profil')
    }).catch(() => { setProfileReady(true); setProfileMessage('Le profil local n’a pas pu être lu. Les données financières restent intactes.') })
  }, [vaultScreen])

  // Chaque réponse et chaque changement d'étape sont chiffrés localement avec un court délai.
  // La progression est remplacée par le profil final à la validation.
  useEffect(() => {
    if (vaultScreen !== 'unlocked' || !profileReady || userProfile || page !== 'Mon profil') return
    const progress: OnboardingProgress = {
      id: 'primary', schemaVersion: 1, status: 'in-progress', currentStep: profileStep,
      startedAt: onboardingStartedAt, updatedAt: new Date().toISOString(), answers: profileDraft,
      dashboard: { visibleCards: dashboardDraft, compact: compactDraft },
    }
    progressSaveQueue.current = progressSaveQueue.current.then(() => saveLocalOnboardingProgress(progress)).then(() => {
        setOnboardingProgress(true)
        setProfileMessage('Progression enregistrée dans le coffre local.')
      }).catch(() => setProfileMessage('La progression n’a pas pu être enregistrée dans le coffre local.'))
  }, [vaultScreen, profileReady, userProfile, page, profileStep, profileDraft, dashboardDraft, compactDraft, onboardingStartedAt])

  async function createMigrationRecoveryFile() {
    if (vaultPassphrase.trim().length < 12) {
      setVaultMessage('Choisis d’abord une phrase secrète d’au moins 12 caractères.')
      return
    }
    setVaultBusy(true)
    setVaultMessage('')
    try {
      const backup = await createLocalBackup(familyId, localRole)
      const encrypted = await encryptBackup(backup, vaultPassphrase)
      const blob = new Blob([JSON.stringify(encrypted)], { type: 'application/octet-stream' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `tena-recovery-${new Date().toISOString().slice(0, 10)}.tenla.enc`
      link.click()
      window.setTimeout(() => URL.revokeObjectURL(url), 1000)
      setVaultBackupDownloaded(true)
      setVaultMessage('Le téléchargement a été demandé. Coche la confirmation après avoir vérifié le fichier.')
    } catch {
      setVaultMessage('La sauvegarde préalable a échoué. Les données existantes sont intactes ; la migration n’a pas commencé.')
    } finally {
      setVaultBusy(false)
    }
  }

  async function setupLocalVault() {
    if (vaultPassphrase !== vaultPassphraseConfirm) {
      setVaultMessage('Les deux phrases secrètes ne correspondent pas.')
      return
    }
    if (vaultHasExistingData && (!vaultBackupDownloaded || !vaultBackupConfirmed)) {
      setVaultMessage('Télécharge d’abord la sauvegarde chiffrée de récupération.')
      return
    }
    setVaultBusy(true)
    setVaultMessage('')
    try {
      await createLocalVaultAndMigrate(vaultPassphrase)
      setVaultPassphrase('')
      setVaultPassphraseConfirm('')
      setVaultScreen('unlocked')
    } catch (error) {
      lockLocalDatabase()
      setVaultScreen('locked')
      setVaultMessage(error instanceof Error ? error.message : 'La migration n’a pas abouti. Les données existantes ont été conservées ; réessaie avec la même phrase secrète.')
    } finally {
      setVaultBusy(false)
    }
  }

  async function unlockLocalVaultScreen() {
    setVaultBusy(true)
    setVaultMessage('')
    try {
      await unlockLocalDatabase(vaultPassphrase)
      setVaultPassphrase('')
      setVaultScreen('unlocked')
    } catch (error) {
      lockLocalDatabase()
      setVaultMessage(error instanceof Error ? error.message : 'Déverrouillage impossible. Les données n’ont pas été modifiées.')
    } finally {
      setVaultBusy(false)
    }
  }

  function lockVaultScreen() {
    lockLocalDatabase()
    setVaultPassphrase('')
    setVaultScreen('locked')
  }

  const thisMonthTransactions = useMemo(() => {
    const today = new Date()
    return transactions.filter(t => {
      const date = new Date(t.bookingDate)
      return date.getMonth() === today.getMonth() && date.getFullYear() === today.getFullYear()
    })
  }, [transactions])

  const totalIncome = useMemo(
    () => thisMonthTransactions.filter(t => t.amountCents > 0).reduce((a, t) => a + t.amountCents, 0),
    [thisMonthTransactions]
  )

  const totalExpenses = useMemo(
    () => Math.abs(thisMonthTransactions.filter(t => t.amountCents < 0).reduce((a, t) => a + t.amountCents, 0)),
    [thisMonthTransactions]
  )

  const balance = totalIncome - totalExpenses

  const filtered = transactions.filter(t =>
    t.label.toLowerCase().includes(search.toLowerCase()) &&
    (!categoryFilter || t.category === categoryFilter)
  )
  const transactionCategories = useMemo(() => [...new Set(transactions.map(t => t.category).filter((x): x is string => Boolean(x)))].sort(), [transactions])
  const budgetCategories = useMemo(() => [...new Set([...transactionCategories, ...budgets.map(b => b.categoryId).filter((x): x is string => Boolean(x))])].sort(), [transactionCategories, budgets])

  const categorySpending = useMemo(() => {
    const totals = new Map<string, number>()
    transactions.filter(t => t.amountCents < 0).forEach(t => {
      const name = t.category || 'Autres'
      totals.set(name, (totals.get(name) || 0) + Math.abs(t.amountCents))
    })
    const entries = [...totals.entries()].sort((a, b) => b[1] - a[1])
    const total = entries.reduce((sum, [, cents]) => sum + cents, 0)
    return entries.slice(0, 5).map(([name, cents]) => ({
      name,
      cents,
      share: total ? Math.round(cents * 100 / total) : 0,
    }))
  }, [transactions])

  const weeklySpending = useMemo(() => Array.from({ length: 7 }, (_, index) => {
    const day = new Date()
    day.setDate(day.getDate() - (6 - index))
    const cents = transactions.filter(t => {
      const date = new Date(t.bookingDate)
      return date.toDateString() === day.toDateString() && t.amountCents < 0
    }).reduce((sum, t) => sum + Math.abs(t.amountCents), 0)
    return { day, cents }
  }), [transactions])

  async function addTransaction() {
    const amountCents = parseEuroCents(amount)
    if (!label.trim() || amountCents === null || amountCents === 0) {
      setToast('Renseigne un libellé et un montant valide.')
      return
    }
    try {
      assertCan(localRole, 'transaction:write')
    } catch {
      setToast('Tu n’as pas la permission d’ajouter une transaction.')
      return
    }

    const tx: Tx = {
      id: `tx_${Date.now()}`,
      label: label.trim(),
      amountCents,
      bookingDate: new Date(),
      category,
    }

    try {
      await saveLocalTransaction({
        id: tx.id,
        familyId,
        amountCents: tx.amountCents,
        bookingDate: tx.bookingDate,
        label: tx.label,
        categoryId: tx.category,
        isDeleted: false,
        syncStatus: 'pending',
        updatedAt: new Date(),
      })
    } catch {
      setToast('La transaction n’a pas pu être enregistrée localement.')
      return
    }

    setTransactions(current => [tx, ...current])
    setLabel('')
    setAmount('')
    setShowAdd(false)
    setToast('Transaction enregistrée localement.')
    setTimeout(() => setToast(''), 2500)
  }

  async function moveTransactionToTrash(transaction: Tx) {
    try {
      assertCan(localRole, 'transaction:delete')
      await softDeleteLocalTransaction(transaction.id, familyId, localRole)
      await refreshLocalData()
      setUserProfile(await getLocalUserProfile())
      setToast('Transaction déplacée dans la corbeille. Elle reste conservée sur cet appareil.')
    } catch (error) {
      const code = error instanceof Error ? error.message : ''
      setToast(code.startsWith('PERMISSION_DENIED') ? 'Tu n’as pas la permission de supprimer cette transaction.' : 'La transaction n’a pas pu être déplacée dans la corbeille.')
    }
    setTimeout(() => setToast(''), 3000)
  }

  async function restoreTransactionFromTrash(transaction: Tx) {
    try {
      assertCan(localRole, 'transaction:write')
      await restoreLocalTransaction(transaction.id, familyId, localRole)
      await refreshLocalData()
      setToast(`« ${transaction.label} » a été restaurée.`)
    } catch (error) {
      const code = error instanceof Error ? error.message : ''
      setToast(code.startsWith('PERMISSION_DENIED') ? 'Tu n’as pas la permission de restaurer cette transaction.' : 'La transaction n’a pas pu être restaurée.')
    }
    setTimeout(() => setToast(''), 2500)
  }

  async function addBudget() {
    const amountCents = parseEuroCents(budgetAmount)
    if (amountCents === null || amountCents <= 0) {
      setToast('Renseigne un budget positif en euros (maximum 2 décimales).')
      return
    }

    try {
      assertCan(localRole, 'budget:write')
      const existingForCore = budgets.map(b => ({
        ...b,
        type: b.month ? 'monthly' as const : 'annual' as const,
        createdAt: b.updatedAt,
      }))
      const coreBudget = createBudget({
        familyId,
        type: budgetType,
        year: budgetYear,
        month: budgetType === 'monthly' ? budgetMonth : undefined,
        categoryId: budgetCategory || undefined,
        amountCents,
      }, localRole, existingForCore)
      const saved: LocalBudget = {
        id: coreBudget.id,
        familyId: coreBudget.familyId,
        amountCents: coreBudget.amountCents,
        year: coreBudget.year,
        month: coreBudget.month,
        categoryId: coreBudget.categoryId,
        syncStatus: 'pending',
        updatedAt: coreBudget.updatedAt,
      }
      await saveLocalBudget(saved)
      setBudgets(current => [saved, ...current])
      setBudgetAmount('')
      setShowAddBudget(false)
      setToast('Budget enregistré sur cet appareil.')
      setTimeout(() => setToast(''), 2500)
    } catch (error) {
      const code = error instanceof Error ? error.message : ''
      const messages: Record<string, string> = {
        BUDGET_DUPLICATE: 'Un budget existe déjà pour cette période et cette catégorie.',
        BUDGET_REQUIRES_OWNER_CONFIRMATION: 'La création de ce montant doit être confirmée par le propriétaire.',
        'BUDGET_REQUIRES_OWNER_CONFIRMATION: >500€': 'La création de ce montant doit être confirmée par le propriétaire.',
        PERMISSION_DENIED: 'Tu n’as pas la permission de créer un budget.',
      }
      setToast(messages[code] || (code.startsWith('PERMISSION_DENIED') ? 'Tu n’as pas la permission de créer un budget.' : 'Le budget n’a pas pu être enregistré.'))
    }
  }

  async function addGoal() {
    const targetCents = parseEuroCents(goalTarget)
    if (!goalName.trim() || targetCents === null || targetCents <= 0) {
      setToast('Renseigne un nom et un montant cible positif.')
      return
    }
    try {
      assertCan(localRole, 'budget:write')
      const goal = createSavingGoal({ familyId, name: goalName, targetCents }, localRole)
      await saveLocalSavingGoal(goal)
      setGoals(current => [ { ...goal, syncStatus: 'pending' }, ...current ])
      setGoalName('')
      setGoalTarget('')
      setShowAddGoal(false)
      setToast('Objectif enregistré sur cet appareil.')
      setTimeout(() => setToast(''), 2500)
    } catch (error) {
      const code = error instanceof Error ? error.message : ''
      setToast(code.startsWith('PERMISSION_DENIED') ? 'Tu n’as pas la permission de créer un objectif.' : 'L’objectif n’a pas pu être enregistré.')
    }
  }

  async function contributeToGoal(goal: LocalSavingGoal) {
    try {
      assertCan(localRole, 'budget:write')
      const result = addContribution(goal, { amountCents: 2500, createdByUserId: 'local-owner' }, localRole, [])
      await saveLocalSavingGoal(result.goal, result.contribution)
      setGoals(current => current.map(item => item.id === goal.id ? { ...result.goal, syncStatus: 'pending' } : item))
      setToast(`Versement de 25 € ajouté à « ${goal.name} ».`)
      setTimeout(() => setToast(''), 2500)
    } catch (error) {
      const code = error instanceof Error ? error.message : ''
      setToast(code.startsWith('PERMISSION_DENIED') ? 'Tu n’as pas la permission de modifier cet objectif.' : 'Le versement n’a pas pu être enregistré.')
    }
  }

  async function downloadLocalBackup() {
    if (backupPassword.length < 8) {
      setToast('Choisis un mot de passe d’au moins 8 caractères.')
      return
    }
    setBackupBusy(true)
    try {
      const backup = await createLocalBackup(familyId, localRole)
      const encrypted = await encryptBackup(backup, backupPassword)
      const blob = new Blob([JSON.stringify(encrypted)], { type: 'application/octet-stream' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `tena-budget-${new Date().toISOString().slice(0, 10)}.tenla.enc`
      link.click()
      window.setTimeout(() => URL.revokeObjectURL(url), 60_000)
      setBackupPassword('')
      setToast('Sauvegarde chiffrée téléchargée.')
      setTimeout(() => setToast(''), 3000)
    } catch {
      setToast('La sauvegarde locale n’a pas pu être créée.')
    } finally {
      setBackupBusy(false)
    }
  }

  async function restoreLocalFile() {
    if (!backupFile) {
      setToast('Sélectionne un fichier .tenla.enc.')
      return
    }
    if (!restorePassword) {
      setToast('Saisis le mot de passe de cette sauvegarde.')
      return
    }
    setBackupBusy(true)
    try {
      const encrypted = JSON.parse(await backupFile.text()) as EncryptedBackup
      const backup = await decryptBackup(encrypted, restorePassword)
      const result = await restoreLocalBackup(backup, familyId, localRole)
      if (!result.restored) {
        setToast(`Aucune donnée écrasée : ${result.conflicts.length} conflit(s) d’identifiant. Choisis une sauvegarde sans doublons.`)
        return
      }
      await refreshLocalData()
      setBackupFile(null)
      setRestorePassword('')
      setToast(`Restauration terminée : ${result.toCreate.transactions} transaction(s), ${result.toCreate.budgets} budget(s), ${result.toCreate.goals} objectif(s), ${result.toCreate.savingContributions} versement(s).`)
      setTimeout(() => setToast(''), 5000)
    } catch (error) {
      const code = error instanceof Error ? error.message : ''
      setToast(code.includes('BACKUP_FAMILY_MISMATCH') ? 'Cette sauvegarde appartient à un autre espace familial.' : code.includes('BACKUP_UNSUPPORTED_DATA') ? 'Cette sauvegarde contient des types de données qui ne sont pas stockés dans cette version locale.' : 'Fichier invalide, mot de passe incorrect ou sauvegarde endommagée.')
    } finally {
      setBackupBusy(false)
    }
  }

  function renderHome() {
    const weekMaxCents = Math.max(1, ...weeklySpending.map(day => day.cents))
    const visible = new Set(userProfile?.dashboard.visibleCards ?? ['spending', 'goals', 'recent-transactions', 'alerts', 'forecast'])
    const hasTransactions = transactions.length > 0
    return <>
      <Card className="balanceHero">
        <div><span className="eyebrow">SOLDE CALCULÉ DEPUIS TES OPÉRATIONS</span><strong>{hasTransactions ? money(balance) : '—'}</strong><small><i /> {hasTransactions ? 'Données locales' : 'Données insuffisantes · ajoute tes opérations'}</small></div>
        <div className="balanceHeroActions">
          <button className="primary" onClick={() => setShowAdd(true)}>＋ Transaction</button>
          <span className="balanceOrnament">TENΛ</span>
        </div>
      </Card>

      {!userProfile ? <Card><div className="cardHead"><div><h2>{onboardingProgress ? 'Ton questionnaire est enregistré' : 'Personnalise ton espace'}</h2><p>{onboardingProgress ? `Reprends à l’étape ${profileStep + 1} : tes réponses sont conservées dans le coffre local.` : 'Définis tes priorités et les cartes à afficher, sans communiquer de montants.'}</p></div><button className="primary" onClick={() => setPage('Mon profil')}>{onboardingProgress ? 'Reprendre le questionnaire →' : 'Faire le questionnaire →'}</button></div></Card> : <Card><div className="cardHead"><div><h2>Accueil adapté à ton profil</h2><small>Priorités : {userProfile.answers.priorities.map(item => ({ 'understand-money': 'comprendre mes finances', 'control-spending': 'contrôler les dépenses', save: 'épargner', 'prepare-expenses': 'prévoir', 'manage-debt': 'gérer les dettes', 'family-visibility': 'organiser le foyer' }[item])).join(' · ')}</small></div><button className="textButton" onClick={() => setPage('Mon profil')}>Modifier →</button></div></Card>}

      <div className="stats homeStats">
        <Card><span><i className="statIcon incomeIcon">↗</i> Revenus du mois</span><strong>{hasTransactions ? money(totalIncome) : '—'}</strong><small>{hasTransactions ? 'Transactions enregistrées' : 'Aucune transaction locale'}</small></Card>
        <Card><span><i className="statIcon expenseIcon">↓</i> Dépenses du mois</span><strong>{hasTransactions ? money(totalExpenses) : '—'}</strong><small>{hasTransactions ? 'Transactions enregistrées' : 'Aucune transaction locale'}</small></Card>
        <Card><span><i className="statIcon balanceIcon">▱</i> Solde net enregistré</span><strong>{hasTransactions ? money(balance) : '—'}</strong><small>{hasTransactions ? 'Calculé depuis les opérations' : 'Données insuffisantes'}</small></Card>
      </div>

      {visible.has('spending') && <Card className="chartCard">
        <div className="cardHead"><div><h2>Évolution des dépenses</h2><small>7 derniers jours · calculé depuis tes transactions</small></div><span className="chartBadge">{hasTransactions ? money(weeklySpending.reduce((sum, day) => sum + day.cents, 0)) : '—'}</span></div>
        {transactions.length === 0 ? <Empty text="Ajoute une transaction pour afficher l’évolution de tes dépenses." /> : <div className="chart"><div className="chartGrid"><span>{money(weekMaxCents)}</span><span>{money(Math.round(weekMaxCents / 2))}</span><span>0 €</span></div>{weeklySpending.map(({day,cents}) => <div key={day.toDateString()} className="barColumn"><div className="bar" title={`${dateText(day)} · ${money(cents)}`} style={{height:`${Math.max(4, Math.min(100, cents / weekMaxCents * 100))}%`}} /><small>{['D','L','M','M','J','V','S'][day.getDay()]}</small></div>)}</div>}
      </Card>}

      <div className="grid2 homeGrid">
        {visible.has('spending') && <Card><div className="cardHead"><h2>Où va mon argent ?</h2><button className="textButton" onClick={() => setPage('Transactions')}>Voir le détail →</button></div>
          {categorySpending.length === 0 ? <Empty text="Les catégories apparaîtront après tes premières dépenses." /> : categorySpending.map((item,i) => <div className="categoryRow" key={item.name}><span className={`categoryIcon category${i}`}>{['◉','⌂','↗','✦','●'][i]}</span><b>{item.name}</b><div className="categoryTrack"><i style={{width:`${Math.max(5,item.share)}%`}} /></div><small>{item.share}%</small><strong>{money(item.cents)}</strong></div>)}
        </Card>}
        {visible.has('goals') && <Card><div className="cardHead"><h2>Objectifs</h2><button className="textButton" onClick={() => setPage('Objectifs')}>Voir tout →</button></div>
          {goals.length === 0 ? <Empty text="Crée un objectif pour suivre ton épargne." /> : goals.slice(0,3).map(g => { const p = Math.min(100, Math.round(g.currentCents / g.targetCents * 100)); return <div className="goal" key={g.id}><div><b>{g.name}</b><span>{money(g.currentCents)} / {money(g.targetCents)}</span></div><div className="progress"><i style={{width:`${p}%`}} /></div><small>{p}% atteint</small></div> })}
        </Card>}
      </div>

      <div className="grid2 homeGrid">
        {visible.has('recent-transactions') && <Card><div className="cardHead"><h2>Transactions récentes</h2><button className="textButton" onClick={() => setPage('Transactions')}>Voir tout →</button></div>{transactions.length === 0 ? <Empty text="Nouvel espace · aucune transaction enregistrée." /> : transactions.slice(0,4).map(t => <TransactionRow key={t.id} tx={t} />)}</Card>}
        {visible.has('alerts') && <Card className="alertsCard"><div className="cardHead"><h2>Alertes locales</h2><button className="textButton" onClick={() => setPage('Notifications')}>Préférences →</button></div><div className="alertRow"><span>✓</span><div><b>Données sur cet appareil</b><small>Les chiffres viennent des transactions enregistrées.</small></div></div><div className="alertRow"><span>↗</span><div><b>{hasTransactions ? 'État des données' : 'Données insuffisantes'}</b><small>{hasTransactions ? `${transactions.length} transaction${transactions.length > 1 ? 's' : ''} locale${transactions.length > 1 ? 's' : ''} pour alimenter les calculs.` : 'Ajoute ou importe des opérations pour alimenter les analyses.'}</small></div></div></Card>}
      </div>
      {visible.has('forecast') && <Card><div className="cardHead"><div><h2>Prévisions</h2><small>Projection conditionnée à un historique suffisant.</small></div><button className="textButton" onClick={() => setPage('Prévisions')}>Ouvrir →</button></div><p>{transactions.length < 3 ? 'Données insuffisantes pour établir une projection fiable.' : 'Ouvre le module Prévisions pour consulter les calculs disponibles.'}</p></Card>}
      <button className="assistantBanner" onClick={() => setPage('IA TENΛ')}><span>✦</span><div><b>Assistant TENΛ</b><small>Disponibilité et sources indiquées dans le module</small></div><strong>→</strong></button>
    </>
  }

  function renderTransactions() {
    const visibleTransactions = showTrash ? deletedTransactions : filtered
    return <Module title="Transactions" subtitle="Toutes tes opérations, stockées localement." action={<button className="primary" onClick={() => setShowAdd(true)}>＋ Ajouter</button>}>
      <div className="toolbar">{!showTrash && <><input placeholder="⌕ Rechercher une transaction..." value={search} onChange={e => setSearch(e.target.value)} /><select aria-label="Filtrer par catégorie" value={categoryFilter} onChange={e => setCategoryFilter(e.target.value)}><option value="">Toutes les catégories</option>{transactionCategories.map(name => <option key={name} value={name}>{name}</option>)}</select><button className="ghost" onClick={() => setToast('L’export des transactions sera disponible depuis Rapports.')}>Exporter</button></>}<button className="ghost" aria-pressed={showTrash} onClick={() => setShowTrash(value => !value)}>{showTrash ? '← Transactions' : `Corbeille (${deletedTransactions.length})`}</button></div>
      <Card>
        {showTrash && <><h2>Corbeille</h2><p>Les opérations sont masquées des totaux et conservées localement. Tu peux les restaurer à tout moment.</p></>}
        {dataLoading ? <Empty text="Chargement des transactions locales…" /> : dataError ? <Empty text={dataError} /> : visibleTransactions.length === 0 ? <Empty text={showTrash ? 'La corbeille est vide.' : transactions.length ? 'Aucune transaction ne correspond à ces filtres.' : 'Aucune transaction enregistrée sur cet appareil.'} /> : <><p className="resultCount">{visibleTransactions.length} transaction{visibleTransactions.length > 1 ? 's' : ''}</p>{visibleTransactions.map(t => <TransactionRow key={t.id} tx={t} onDelete={showTrash ? undefined : () => void moveTransactionToTrash(t)} onRestore={showTrash ? () => void restoreTransactionFromTrash(t) : undefined} />)}</>}
      </Card>
    </Module>
  }

  function renderBudget() {
    const visibleBudgets = budgets.filter(b => b.year === selectedBudgetYear && (b.month === undefined || b.month === selectedBudgetMonth))
    const expensesFor = (budget: LocalBudget) => transactions.reduce((sum, tx) => {
      const date = new Date(tx.bookingDate)
      const inPeriod = date.getFullYear() === budget.year && (budget.month === undefined || date.getMonth() + 1 === budget.month)
      const matchesCategory = !budget.categoryId || tx.category === budget.categoryId
      const matchesPerson = !budget.personId || tx.personId === budget.personId
      return inPeriod && matchesCategory && matchesPerson && tx.amountCents < 0 ? sum + Math.abs(tx.amountCents) : sum
    }, 0)
    const years = [...new Set([new Date().getFullYear(), ...budgets.map(b => b.year)])].sort((a,b) => b-a)

    return <Module title="Budget" subtitle="Budgets enregistrés sur cet appareil et dépenses réelles par période." action={<button className="primary" onClick={() => { setBudgetYear(selectedBudgetYear); setBudgetMonth(selectedBudgetMonth); setShowAddBudget(true) }}>＋ Nouveau budget</button>}>
      <div className="toolbar budgetFilters"><select aria-label="Année du budget" value={selectedBudgetYear} onChange={e => setSelectedBudgetYear(Number(e.target.value))}>{years.map(year => <option key={year} value={year}>{year}</option>)}</select><select aria-label="Mois du budget" value={selectedBudgetMonth} onChange={e => setSelectedBudgetMonth(Number(e.target.value))}>{Array.from({length:12},(_,i)=>i+1).map(month => <option key={month} value={month}>{new Intl.DateTimeFormat('fr-FR',{month:'long'}).format(new Date(2020,month-1,1))}</option>)}</select></div>
      {dataLoading ? <Card><Empty text="Chargement des budgets locaux…" /></Card> : dataError ? <Card><Empty text={dataError} /></Card> : visibleBudgets.length === 0 ? <Card><Empty text={`Aucun budget enregistré pour ${selectedBudgetMonth}/${selectedBudgetYear}. Crée ton premier budget avec « Nouveau budget ».`} /></Card> : <div className="budgetGrid">
        {visibleBudgets.map(b => {
          const spent = expensesFor(b)
          const p = b.amountCents ? Math.floor(spent * 100 / b.amountCents) : 0
          return <Card key={b.id}><div className="budgetTitle"><b>{b.categoryId || 'Toutes catégories'}</b><span>{b.month ? 'Mensuel' : 'Annuel'}</span></div><small className="budgetPeriod">{b.month ? `${String(b.month).padStart(2,'0')}/${b.year}` : b.year}</small><div className="progress"><i style={{width:`${Math.min(100,p)}%`}} /></div><div className="budgetNumbers"><strong>{money(spent)}</strong><span>sur {money(b.amountCents)}</span></div><small>{money(b.amountCents-spent)} restant · {p}% consommé</small></Card>
        })}
      </div>}
      <Card><h2>Analyse du budget</h2><p>Les dépenses sont calculées depuis les transactions locales non supprimées, pour la même catégorie, personne et période.</p></Card>
    </Module>
  }

  function renderGoals() {
    return <Module title="Objectifs" subtitle="Tes objectifs d’épargne enregistrés sur cet appareil." action={<button className="primary" onClick={() => setShowAddGoal(true)}>＋ Nouvel objectif</button>}>
      {dataLoading ? <Card><Empty text="Chargement des objectifs locaux…" /></Card> : dataError ? <Card><Empty text={dataError} /></Card> : goals.length === 0 ? <Card><Empty text="Aucun objectif enregistré. Crée ton premier objectif pour suivre ton épargne." /></Card> : <div className="budgetGrid">{goals.map(g => {
        const p = Math.max(0, Math.floor(g.currentCents * 100 / g.targetCents))
        return <Card key={g.id}><div className="goalBig"><span>◎</span><div><b>{g.name}</b><small>{money(g.targetCents)} objectif</small></div></div><div className="progress"><i style={{width:`${Math.min(100,p)}%`}} /></div><div className="budgetNumbers"><strong>{money(g.currentCents)}</strong><span>{p}%</span></div><button className="ghost" disabled={g.isArchived} onClick={() => contributeToGoal(g)}>＋ Ajouter 25 €</button></Card>
      })}</div>}
    </Module>
  }

  function renderBackups() {
    return <Module title="Sauvegardes" subtitle="Protège et restaure les données réellement présentes sur cet appareil.">
      <div className="budgetGrid">
        <Card><h2>Créer une sauvegarde chiffrée</h2><p>Inclut les transactions non supprimées, budgets, objectifs et versements enregistrés dans TENΛ Budget sur cet appareil. Le fichier est chiffré avec AES-GCM avant téléchargement.</p><label className="backupLabel">Mot de passe de sauvegarde<input type="password" autoComplete="new-password" value={backupPassword} onChange={event => setBackupPassword(event.target.value)} placeholder="8 caractères minimum" /></label><button className="primary full" disabled={backupBusy} onClick={downloadLocalBackup}>{backupBusy ? 'Préparation…' : 'Chiffrer et télécharger .tenla.enc'}</button></Card>
        <Card><h2>Restaurer sans écraser</h2><p>La restauration vérifie le chiffrement, l’intégrité et l’espace familial. En cas d’identifiants déjà présents, rien n’est écrit et les conflits sont signalés.</p><label className="backupLabel">Fichier .tenla.enc<input type="file" accept=".tenla.enc,application/json" onChange={event => setBackupFile(event.target.files?.[0] ?? null)} /></label><label className="backupLabel">Mot de passe de cette sauvegarde<input type="password" autoComplete="current-password" value={restorePassword} onChange={event => setRestorePassword(event.target.value)} placeholder="Mot de passe" /></label><button className="primary full" disabled={backupBusy} onClick={restoreLocalFile}>{backupBusy ? 'Vérification…' : 'Vérifier et restaurer localement'}</button></Card>
      </div>
      <Card><h2>Portée de la sauvegarde locale</h2><p>Les transactions, budgets, objectifs et versements sont persistés par Dexie. Les catégories, personnes et règles récurrentes n’ont pas de table dans ce stockage local et ne sont donc ni simulées ni incluses. Les restaurations gardent les enregistrements existants et ajoutent les éléments sans conflit de façon atomique.</p></Card>
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

  async function saveProfileDraft() {
    setProfileBusy(true)
    setProfileMessage('')
    try {
      const suggested = createUserProfile(profileDraft)
      const next = userProfile
        ? updateUserProfile(userProfile, { answers: profileDraft, visibleCards: dashboardDraft.length ? dashboardDraft : suggested.dashboard.visibleCards, compact: compactDraft })
        : updateUserProfile(suggested, { visibleCards: dashboardDraft.length ? dashboardDraft : suggested.dashboard.visibleCards, compact: compactDraft })
      await progressSaveQueue.current
      await saveLocalUserProfile(next)
      setUserProfile(next)
      setOnboardingProgress(false)
      setProfileMessage('Profil enregistré et chiffré sur cet appareil. Le tableau de bord est maintenant adapté à tes réponses.')
      setPage('Accueil')
    } catch (error) {
      setProfileMessage(error instanceof Error ? `Impossible d’enregistrer : ${error.message}` : 'Impossible d’enregistrer le profil.')
    } finally {
      setProfileBusy(false)
    }
  }

  function toggleProfileChoice<T extends string>(current: T[], value: T): T[] {
    return current.includes(value) ? current.filter(item => item !== value) : [...current, value]
  }

  function renderProfile() {
    const draftRecommendation = profileDraft.priorities.length ? recommendForProfile(createUserProfile(profileDraft)) : undefined
    const setAnswer = <K extends keyof OnboardingAnswers>(key: K, value: OnboardingAnswers[K]) => setProfileDraft(current => ({ ...current, [key]: value }))
    const choice = (label: string, selected: boolean, onClick: () => void) => <button type="button" className={selected ? 'primary' : 'ghost'} onClick={onClick} style={{ margin: '4px 6px 4px 0', padding: '9px 12px' }} aria-pressed={selected}>{label}</button>
    const priorities: { id: UserPriority; label: string }[] = [
      { id: 'understand-money', label: 'Comprendre où va mon argent' }, { id: 'control-spending', label: 'Mieux contrôler mes dépenses' },
      { id: 'save', label: 'Épargner pour mes projets' }, { id: 'prepare-expenses', label: 'Préparer les dépenses à venir' },
      { id: 'manage-debt', label: 'Mieux gérer mes crédits et dettes' }, { id: 'family-visibility', label: 'Organiser les finances du foyer' },
    ]
    return <Module title="Mon profil financier" subtitle="Quelques réponses pour adapter l’accueil. Aucun montant ni identifiant bancaire n’est demandé.">
      {profileMessage && <Card><p role="status">{profileMessage}</p></Card>}
      <Card>
        <div className="cardHead"><h2>{userProfile ? 'Mettre à jour mon profil' : 'Construisons ton espace personnel'}</h2><span className="pill">Étape {profileStep + 1} / 5</span></div>
        <div className="progress"><i style={{ width: `${(profileStep + 1) * 20}%` }} /></div>
        {profileStep === 0 && <section><h3>Pour quel type de foyer gères-tu ton budget ?</h3><p>Tu pourras changer cette réponse plus tard.</p>
          {choice('Personnel', profileDraft.householdMode === 'personal', () => setAnswer('householdMode', 'personal'))}{choice('En couple', profileDraft.householdMode === 'couple', () => setAnswer('householdMode', 'couple'))}{choice('Famille', profileDraft.householdMode === 'family', () => setAnswer('householdMode', 'family'))}{choice('Projet professionnel plus tard', profileDraft.householdMode === 'business-later', () => setAnswer('householdMode', 'business-later'))}
        </section>}
        {profileStep === 1 && <section><h3>Comment décrirais-tu tes revenus ?</h3>
          {choice('Plutôt réguliers', profileDraft.incomePattern === 'regular', () => setAnswer('incomePattern', 'regular'))}{choice('Variables', profileDraft.incomePattern === 'variable', () => setAnswer('incomePattern', 'variable'))}{choice('Un mélange des deux', profileDraft.incomePattern === 'mixed', () => setAnswer('incomePattern', 'mixed'))}{choice('Je préfère ne pas préciser', profileDraft.incomePattern === 'prefer-not-to-say', () => setAnswer('incomePattern', 'prefer-not-to-say'))}
          <h3 style={{ marginTop: 20 }}>Ton expérience du budget ?</h3>{choice('Je commence', profileDraft.budgetExperience === 'starting', () => setAnswer('budgetExperience', 'starting'))}{choice('J’ai déjà quelques habitudes', profileDraft.budgetExperience === 'some-habits', () => setAnswer('budgetExperience', 'some-habits'))}{choice('Je suis expérimenté(e)', profileDraft.budgetExperience === 'experienced', () => setAnswer('budgetExperience', 'experienced'))}
        </section>}
        {profileStep === 2 && <section><h3>Qu’aimerais-tu améliorer en priorité ?</h3><p>Choisis un ou plusieurs sujets. Ils détermineront l’ordre des cartes du tableau de bord.</p>{priorities.map(item => choice(item.label, profileDraft.priorities.includes(item.id), () => { const next = toggleProfileChoice(profileDraft.priorities, item.id); setAnswer('priorities', next); if (next.length) setDashboardDraft(createUserProfile({ ...profileDraft, priorities: next }).dashboard.visibleCards) }))}</section>}
        {profileStep === 3 && <section><h3>Quelles fonctions t’intéressent ?</h3><p>Le statut indique ce qui marche déjà et ce qui reste à construire. Cela ne souscrit à aucune offre et n’active aucune banque.</p><div style={{ maxHeight: 330, overflow: 'auto' }}>{PRODUCT_CAPABILITIES.map(feature => <label key={feature.id} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: 10, borderBottom: '1px solid #eee8dc', cursor: 'pointer' }}><input type="checkbox" checked={profileDraft.wantedFeatures.includes(feature.id)} onChange={() => setAnswer('wantedFeatures', toggleProfileChoice(profileDraft.wantedFeatures, feature.id))} /><span><b>{feature.label}</b><small style={{ display: 'block', color: '#746b5e' }}>{feature.status === 'available-local' ? 'Disponible localement' : feature.status === 'partial' ? 'Partiel — intégration à poursuivre' : feature.status === 'mock-only' ? 'Mock uniquement — pas de banque réelle' : 'Prévu, non disponible'} · {feature.note}</small></span></label>)}</div><h3 style={{ marginTop: 18 }}>Fréquence des notifications</h3>{choice('Essentielles seulement', profileDraft.notificationPreference === 'essential', () => setAnswer('notificationPreference', 'essential'))}{choice('Équilibrée', profileDraft.notificationPreference === 'balanced', () => setAnswer('notificationPreference', 'balanced'))}{choice('Aucune', profileDraft.notificationPreference === 'none', () => setAnswer('notificationPreference', 'none'))}</section>}
        {profileStep === 4 && <section><h3>Choisis les cartes de ton tableau de bord</h3><p>Les chiffres affichés viendront uniquement des transactions, budgets et objectifs réellement enregistrés sur cet appareil.</p>
          {([{ id: 'spending', label: 'Répartition et évolution des dépenses' }, { id: 'goals', label: 'Objectifs d’épargne' }, { id: 'recent-transactions', label: 'Transactions récentes' }, { id: 'alerts', label: 'Conseils et alertes locales' }, { id: 'forecast', label: 'Prévisions' }] as { id: DashboardCardId; label: string }[]).map(item => <label key={item.id} style={{ display: 'flex', gap: 8, padding: '7px 0' }}><input type="checkbox" checked={dashboardDraft.includes(item.id)} onChange={() => setDashboardDraft(current => toggleProfileChoice(current, item.id))} /> {item.label}</label>)}
          <label style={{ display: 'flex', gap: 8, padding: '8px 0' }}><input type="checkbox" checked={compactDraft} onChange={event => setCompactDraft(event.target.checked)} /> Affichage compact</label>
          <h3>Formule correspondant à tes besoins</h3><strong style={{ fontSize: 22, textTransform: 'capitalize' }}>{(draftRecommendation?.offerProjection.tier ?? 'free').replace('-', '+')}</strong><p>Projection produit uniquement. Aucun tarif n’est configuré et aucun paiement ou déverrouillage n’est effectué.</p>
          <h3>Fonctions déjà disponibles ou partielles</h3><p>{draftRecommendation?.availableFeatures.map(id => PRODUCT_CAPABILITIES.find(item => item.id === id)?.label).join(' · ') || 'Aucune sélection'}</p>
          <h3>À venir ou mock</h3><p>{draftRecommendation?.upcomingFeatures.map(id => PRODUCT_CAPABILITIES.find(item => item.id === id)?.label).join(' · ') || 'Aucune'}</p>
        </section>}
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 22 }}><button className="ghost" disabled={profileStep === 0} onClick={() => setProfileStep(step => Math.max(0, step - 1))}>← Retour</button>{profileStep < 4 ? <button className="primary" disabled={profileStep === 2 && !profileDraft.priorities.length} onClick={() => setProfileStep(step => Math.min(4, step + 1))}>Continuer →</button> : <button className="primary" disabled={profileBusy} onClick={() => void saveProfileDraft()}>{profileBusy ? 'Enregistrement local…' : 'Enregistrer et ouvrir mon tableau de bord'}</button>}</div>
      </Card>
      {userProfile && <Card><h3>Vie privée</h3><p>Les réponses sont chiffrées dans le coffre local et incluses dans les sauvegardes chiffrées. Elles ne sont pas envoyées à un serveur.</p><button className="ghost" onClick={() => { setProfileStep(0); setPage('Mon profil') }}>Revoir mes réponses</button></Card>}
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
      case 'Sauvegardes': return renderBackups()
      case 'Famille': return renderFamily()
      case 'Entreprise': return renderEnterprise()
      case 'Autopilot': return renderAutopilot()
      case 'Mon profil': return renderProfile()
      case 'Paramètres': return renderSettings()
    }
  }

  if (vaultScreen !== 'unlocked') {
    const checking = vaultScreen === 'checking'
    const setup = vaultScreen === 'setup'
    return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 20, background: '#f8f6f1', color: '#17233f', fontFamily: 'Inter, system-ui, sans-serif' }}>
      <section style={{ width: 'min(100%, 520px)', background: '#fff', border: '1px solid #eee5d3', borderRadius: 18, padding: 28, boxShadow: '0 12px 40px #3b2b1014' }}>
        <div style={{ color: '#bd8815', fontSize: 13, fontWeight: 700, letterSpacing: '.12em' }}>TENΛ BUDGET</div>
        {checking ? <><h1>Ouverture du coffre local…</h1><p>Les données personnelles restent verrouillées pendant la vérification.</p></> : setup ? <>
          <h1>Protéger ce profil sur cet appareil</h1>
          <p>Une phrase secrète chiffre les données financières enregistrées localement. Elle n’est pas envoyée à un serveur et doit être saisie après rechargement.</p>
          {vaultHasExistingData && <div style={{ background: '#fff8e8', border: '1px solid #ead7a7', borderRadius: 10, padding: 14, margin: '18px 0' }}>
            <b>Des données existantes ont été trouvées.</b>
            <p style={{ marginBottom: 8 }}>Avant leur migration, télécharge une sauvegarde chiffrée de récupération avec la même phrase secrète. La migration reprend sans supprimer les lignes existantes si elle est interrompue.</p>
            <button disabled={vaultBusy || vaultBackupDownloaded} onClick={() => void createMigrationRecoveryFile()} style={{ padding: '10px 14px' }}>{vaultBackupDownloaded ? 'Sauvegarde téléchargée' : 'Télécharger la sauvegarde chiffrée'}</button>
            {vaultBackupDownloaded && <label style={{ display: 'block', marginTop: 10 }}><input type="checkbox" checked={vaultBackupConfirmed} onChange={event => setVaultBackupConfirmed(event.target.checked)} /> J’ai vérifié que le fichier de récupération est enregistré.</label>}
          </div>}
          <label style={{ display: 'block', marginTop: 14 }}>Phrase secrète (12 caractères minimum)<input autoComplete="new-password" type="password" value={vaultPassphrase} onChange={event => setVaultPassphrase(event.target.value)} style={{ display: 'block', width: '100%', marginTop: 6, padding: 12, border: '1px solid #ddd4c5', borderRadius: 8 }} /></label>
          <label style={{ display: 'block', marginTop: 12 }}>Confirmer la phrase secrète<input autoComplete="new-password" type="password" value={vaultPassphraseConfirm} onChange={event => setVaultPassphraseConfirm(event.target.value)} style={{ display: 'block', width: '100%', marginTop: 6, padding: 12, border: '1px solid #ddd4c5', borderRadius: 8 }} /></label>
          <button className="primary" disabled={vaultBusy || (vaultHasExistingData && (!vaultBackupDownloaded || !vaultBackupConfirmed))} onClick={() => void setupLocalVault()} style={{ width: '100%', padding: 13, border: 0, borderRadius: 8, marginTop: 18 }}>{vaultBusy ? 'Migration sécurisée…' : 'Chiffrer et ouvrir mon espace'}</button>
        </> : <>
          <h1>Déverrouiller le stockage local</h1>
          <p>Les données et la clé de chiffrement ne quittent pas cet appareil. Pour ouvrir un autre appareil, restaure une sauvegarde chiffrée dans ce profil.</p>
          <form onSubmit={event => { event.preventDefault(); void unlockLocalVaultScreen() }}><label style={{ display: 'block', marginTop: 14 }}>Phrase secrète du coffre<input autoComplete="current-password" type="password" autoFocus value={vaultPassphrase} onChange={event => setVaultPassphrase(event.target.value)} style={{ display: 'block', width: '100%', marginTop: 6, padding: 12, border: '1px solid #ddd4c5', borderRadius: 8 }} /></label><button className="primary" disabled={vaultBusy} style={{ width: '100%', padding: 13, border: 0, borderRadius: 8, marginTop: 18 }}>{vaultBusy ? 'Déverrouillage…' : 'Déverrouiller'}</button></form>
          <small style={{ display: 'block', marginTop: 14 }}>Une phrase secrète oubliée ne peut pas être récupérée par TENΛ. Utilise ta sauvegarde chiffrée pour restaurer les données.</small>
        </>}
        {vaultMessage && <p role="status" style={{ color: '#9d3c2e', marginTop: 14 }}>{vaultMessage}</p>}
      </section>
    </main>
  }

  if (vaultScreen === 'unlocked' && !profileReady) return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', color: '#17233f' }}>Chargement du profil local…</main>

  return <div className={`${dark ? 'app dark' : 'app'}${userProfile?.dashboard.compact ? ' profileCompact' : ''}`}>
    <aside className="sidebar">
      <div className="brand"><div className="logo">△</div><div><b>TENΛ Budget</b></div><span className="goldPill">OR</span></div>
      <div className="profileCard"><div className="profileAvatar">L</div><div><b>Mon espace</b><small>Profil personnel</small></div><span>⌄</span></div>
      <div className="workspace">ESPACE PERSONNEL</div>
      <nav>{pages.map((p,index) => <React.Fragment key={p.name}>{p.group && pages[index-1]?.group !== p.group && <div className="navGroup">{p.group}</div>}<button className={page===p.name?'active':''} onClick={()=>setPage(p.name)}><i>{p.icon}</i>{p.name}</button></React.Fragment>)}</nav>
      <div className="offline"><span>●</span><div><b>Hors ligne</b><small>Données locales</small></div></div>
    </aside>

    <main>
      <header><div className="breadcrumb">{page}</div><div className="topbarBrand">TENΛ <span>Budget</span></div><div className="topActions"><input className="globalSearch" placeholder="⌕ Rechercher..." value={search} onChange={e=>setSearch(e.target.value)} /><button className="iconBtn" aria-label="Notifications" onClick={()=>setPage('Notifications')}>♢</button><button className="iconBtn" title="Verrouiller les données" onClick={lockVaultScreen}>⌑</button><button className="avatar">L</button></div></header>
      <section className="content">{content()}</section>
    </main>

    {showAdd && <div className="modalBack" onClick={()=>setShowAdd(false)}><div className="modal" onClick={e=>e.stopPropagation()}><div className="cardHead"><h2>Nouvelle transaction</h2><button className="iconBtn" onClick={()=>setShowAdd(false)}>×</button></div><label>Libellé<input value={label} onChange={e=>setLabel(e.target.value)} placeholder="Ex. Courses" /></label><label>Montant (€)<input value={amount} onChange={e=>setAmount(e.target.value)} placeholder="-42,50" /></label><label>Catégorie<select value={category} onChange={e=>setCategory(e.target.value)}><option>Alimentation</option><option>Transport</option><option>Loisirs</option><option>Abonnements</option><option>Autre</option></select></label><button className="primary full" onClick={addTransaction}>Enregistrer localement</button></div></div>}

    {showAddBudget && <div className="modalBack" onClick={()=>setShowAddBudget(false)}><div className="modal" onClick={e=>e.stopPropagation()}><div className="cardHead"><h2>Nouveau budget</h2><button className="iconBtn" onClick={()=>setShowAddBudget(false)}>×</button></div><label>Montant maximum (€)<input inputMode="decimal" value={budgetAmount} onChange={e=>setBudgetAmount(e.target.value)} placeholder="Ex. 350,00" /></label><label>Catégorie<select value={budgetCategory} onChange={e=>setBudgetCategory(e.target.value)}><option value="">Toutes les catégories</option>{budgetCategories.map(name=><option key={name} value={name}>{name}</option>)}</select></label><label>Période<select value={budgetType} onChange={e=>setBudgetType(e.target.value as 'annual'|'monthly')}><option value="monthly">Mensuelle</option><option value="annual">Annuelle</option></select></label>{budgetType === 'monthly' && <label>Mois<select value={budgetMonth} onChange={e=>setBudgetMonth(Number(e.target.value))}>{Array.from({length:12},(_,i)=>i+1).map(month=><option key={month} value={month}>{new Intl.DateTimeFormat('fr-FR',{month:'long'}).format(new Date(2020,month-1,1))}</option>)}</select></label>}<label>Année<input type="number" min="2000" max="2200" value={budgetYear} onChange={e=>setBudgetYear(Number(e.target.value))} /></label><button className="primary full" onClick={addBudget}>Enregistrer le budget</button></div></div>}

    {showAddGoal && <div className="modalBack" onClick={()=>setShowAddGoal(false)}><div className="modal" onClick={e=>e.stopPropagation()}><div className="cardHead"><h2>Nouvel objectif</h2><button className="iconBtn" aria-label="Fermer" onClick={()=>setShowAddGoal(false)}>×</button></div><label>Nom de l’objectif<input value={goalName} onChange={e=>setGoalName(e.target.value)} placeholder="Ex. Vacances" /></label><label>Montant cible (€)<input inputMode="decimal" value={goalTarget} onChange={e=>setGoalTarget(e.target.value)} placeholder="Ex. 2 000,00" /></label><button className="primary full" onClick={addGoal}>Enregistrer localement</button></div></div>}

    {toast && <div className="toast">{toast}</div>}

    <style>{styles}</style>
  </div>
}

function Module({title,subtitle,action,children}:{title:string;subtitle:string;action?:React.ReactNode;children:React.ReactNode}) {
  return <><div className="moduleHead"><div><div className="eyebrow">TENΛ BUDGET</div><h1>{title}</h1><p>{subtitle}</p></div>{action}</div>{children}</>
}

function TransactionRow({tx,onDelete,onRestore}:{tx:Tx;onDelete?:()=>void;onRestore?:()=>void}) {
  const positive = tx.amountCents > 0
  return <div className="tx"><div className="txIcon">{positive?'↗':'↘'}</div><div className="txMain"><b>{tx.label}</b><small>{tx.category || 'Non catégorisé'} · {dateText(tx.bookingDate)}{tx.deletedAt ? ` · supprimée le ${dateText(tx.deletedAt)}` : ''}</small></div><strong className={positive?'positive':'negative'}>{positive?'+':''}{money(tx.amountCents)}</strong>{onDelete && <button className="textButton" aria-label={`Déplacer ${tx.label} dans la corbeille`} onClick={onDelete}>Supprimer</button>}{onRestore && <button className="textButton" aria-label={`Restaurer ${tx.label}`} onClick={onRestore}>Restaurer</button>}</div>
}

function Empty({text}:{text:string}) { return <div className="empty"><span>□</span><p>{text}</p></div> }
function Setting({title,desc,control}:{title:string;desc:string;control:React.ReactNode}) { return <div className="setting"><div><b>{title}</b><p>{desc}</p></div>{control}</div> }

const styles = `
*{box-sizing:border-box}body{margin:0;font-family:Inter,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:#080b12;color:#eef2f7}button,input,select{font:inherit}button{cursor:pointer}.app{min-height:100vh;background:#f4f6f8;color:#18202c;display:flex}.app.dark{background:#090d14;color:#eef2f7}.sidebar{width:248px;min-height:100vh;background:#0d121b;border-right:1px solid #202936;padding:22px 14px;position:fixed;left:0;top:0;bottom:0;overflow:auto}.brand{display:flex;align-items:center;gap:11px;padding:0 10px 24px}.logo{width:38px;height:38px;border-radius:11px;display:grid;place-items:center;background:#fff;color:#080b12;font-size:23px;font-weight:900}.brand b{display:block;font-size:18px}.brand small{color:#8994a5}.workspace{font-size:10px;letter-spacing:1.5px;color:#778397;padding:13px 12px;border-top:1px solid #202936;border-bottom:1px solid #202936;margin-bottom:10px}.workspace span{float:right}nav button{display:flex;width:100%;border:0;background:transparent;color:#9da8b9;text-align:left;padding:10px 12px;border-radius:9px;align-items:center;gap:11px;margin:2px 0}nav button:hover{background:#171e29;color:#fff}nav button.active{background:#fff;color:#0a0e15;font-weight:700}.dark nav button.active{background:#eef2f7}.navGroup{font-size:9px;text-transform:uppercase;letter-spacing:1.5px;color:#596679;margin:18px 12px 6px}.offline{position:absolute;bottom:18px;left:14px;right:14px;background:#121a25;border:1px solid #263141;border-radius:10px;padding:10px;display:flex;gap:9px}.offline span{color:#52d68a}.offline b,.offline small{display:block}.offline small{color:#778397;font-size:11px;margin-top:2px}main{margin-left:248px;width:calc(100% - 248px);min-width:0}header{height:68px;border-bottom:1px solid #dce1e8;background:#fff;display:flex;align-items:center;justify-content:space-between;padding:0 30px;position:sticky;top:0;z-index:5}.dark header{background:#0d121b;border-color:#202936}.breadcrumb{font-weight:700}.breadcrumb span{color:#8994a5;margin:0 8px}.topActions{display:flex;align-items:center;gap:10px}.globalSearch{width:210px;background:#f3f5f7;border:1px solid #e0e4e9;border-radius:8px;padding:9px 12px;outline:none}.dark .globalSearch{background:#141b25;border-color:#293444;color:#fff}.iconBtn,.avatar,.ghost{border:1px solid #dfe4ea;background:transparent;border-radius:8px;padding:8px 11px}.dark .iconBtn,.dark .ghost{border-color:#2a3544;color:#dce3ec}.avatar{width:35px;height:35px;padding:0;border-radius:50%;background:#202938;color:#fff;border:0}.content{padding:32px;max-width:1500px;margin:auto}.hero,.moduleHead{display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:28px}.hero h1,.moduleHead h1{font-size:31px;margin:5px 0}.hero p,.moduleHead p{color:#7d8899;margin:0}.eyebrow{font-size:10px;letter-spacing:2px;font-weight:800;color:#718096}.primary{border:0;border-radius:8px;background:#fff;color:#080b12;padding:10px 15px;font-weight:750}.dark .primary{background:#f2f5f8}.full{width:100%;margin-top:10px}.stats{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:16px}.card{background:#fff;border:1px solid #dfe4ea;border-radius:12px;padding:20px;margin-bottom:16px}.dark .card{background:#101620;border-color:#222d3b}.stats .card span,.stats .card small{display:block;color:#7d8899}.stats .card strong{display:block;font-size:26px;margin:10px 0 5px}.grid2{display:grid;grid-template-columns:1.35fr 1fr;gap:16px}.grid2>.card{margin:0}.cardHead{display:flex;align-items:center;justify-content:space-between;margin-bottom:16px}.card h2{font-size:16px;margin:0}.chart{height:190px;display:flex;align-items:end;gap:10px;padding:20px 8px 0}.bar{flex:1;border-radius:5px 5px 2px 2px;background:#758196;min-height:12px}.chartLabels{display:flex;justify-content:space-between;color:#788496;font-size:10px}.goal{margin:17px 0}.goal>div:first-child{display:flex;justify-content:space-between}.goal span,.goal small{color:#7c8798;font-size:12px}.progress{height:7px;background:#e4e8ed;border-radius:10px;overflow:hidden;margin:8px 0}.dark .progress{background:#222c39}.progress i{display:block;height:100%;background:#778397;border-radius:10px}.aiCard{background:linear-gradient(145deg,#111925,#171f2c)!important;color:#fff}.aiCard p{color:#aab4c2;line-height:1.6}.aiIcon{font-size:28px;margin-bottom:12px}.tx{display:flex;align-items:center;gap:12px;padding:13px 0;border-bottom:1px solid #e4e8ed}.dark .tx{border-color:#242d3a}.tx:last-child{border:0}.txIcon{width:34px;height:34px;border-radius:9px;background:#edf0f3;display:grid;place-items:center;color:#566274}.dark .txIcon{background:#1c2531}.txMain{flex:1}.txMain b,.txMain small{display:block}.txMain small{color:#7d8899;font-size:11px;margin-top:3px}.positive{color:#429a68}.negative{color:#c75e64}.toolbar{display:flex;gap:10px;margin-bottom:16px}.toolbar input,.toolbar select{flex:1;padding:10px 12px;border:1px solid #dfe4ea;border-radius:8px;background:#fff;outline:none}.dark .toolbar input,.dark .toolbar select{background:#101620;border-color:#293444;color:#fff}.budgetGrid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}.budgetGrid>.card{margin:0}.budgetTitle,.budgetNumbers{display:flex;justify-content:space-between;align-items:center}.budgetTitle span{color:#7c8798}.budgetNumbers{margin-top:10px}.budgetNumbers span{color:#7c8798;font-size:12px}.goalBig{display:flex;gap:12px;align-items:center;margin-bottom:20px}.goalBig>span{font-size:30px}.goalBig b,.goalBig small{display:block}.goalBig small{color:#7d8899;margin-top:3px}.scenario,.member,.notice,.setting{display:flex;align-items:center;gap:15px;padding:16px 0;border-bottom:1px solid #e4e8ed}.dark .scenario,.dark .member,.dark .notice,.dark .setting{border-color:#252e3a}.scenario span,.scenario strong{margin-left:auto}.scenario span{color:#7d8899}.chat{min-height:500px}.aiBubble{max-width:650px;background:#161e2b;border:1px solid #293545;border-radius:12px;padding:16px}.aiBubble p{color:#b0bac8}.suggestions{display:flex;gap:8px;flex-wrap:wrap;margin:20px 0}.suggestions button{background:transparent;color:inherit;border:1px solid #344052;border-radius:20px;padding:9px 13px}.chatInput{display:flex;gap:10px;margin-top:250px}.chatInput input{flex:1;padding:12px;border:1px solid #303b4c;border-radius:8px;background:#0d131d;color:#fff}.reportIcon{font-size:25px}.drop{text-align:center;padding:60px}.drop>div{font-size:42px}.notice>span{font-size:22px}.notice p{margin:4px 0 0;color:#7d8899}.member .avatar{display:grid;place-items:center}.member div:nth-child(2){flex:1}.member small{display:block;color:#7d8899;margin-top:3px}.pill{font-size:9px;letter-spacing:1px;padding:5px 8px;border-radius:20px;background:#e8ebef;color:#5d6878}.dark .pill{background:#202a37;color:#b9c3d1}.autopilot{text-align:center;padding:50px}.steps{display:flex;justify-content:center;gap:12px;flex-wrap:wrap;margin:25px}.steps span{padding:10px 14px;background:#182130;border-radius:8px}.setting>div{flex:1}.setting p{margin:5px 0 0;color:#7d8899}.empty{text-align:center;padding:45px;color:#7d8899}.empty span{font-size:30px}.modalBack{position:fixed;inset:0;background:#0009;display:grid;place-items:center;z-index:20}.modal{width:min(450px,90vw);background:#fff;color:#18202c;border-radius:14px;padding:22px;box-shadow:0 20px 80px #0008}.dark .modal{background:#111823;color:#fff}.modal label{display:block;font-size:12px;font-weight:700;margin:15px 0}.modal input,.modal select{display:block;width:100%;margin-top:6px;padding:11px;border:1px solid #dce1e8;border-radius:8px;background:transparent;color:inherit}.toast{position:fixed;right:25px;bottom:25px;background:#151d29;color:#fff;border:1px solid #344052;border-radius:10px;padding:13px 17px;z-index:30;box-shadow:0 10px 30px #0005}@media(max-width:900px){.sidebar{width:76px}.brand div:not(.logo),.workspace,nav button:not(.active)::after,nav button{font-size:0}.brand{padding:0 5px 24px}.logo{margin:auto}.sidebar nav button{justify-content:center;font-size:20px}.sidebar nav button i{font-size:20px}main{margin-left:76px;width:calc(100% - 76px)}.stats{grid-template-columns:repeat(2,1fr)}.grid2{grid-template-columns:1fr}.content{padding:20px}.globalSearch{display:none}}@media(max-width:600px){.budgetGrid,.stats{grid-template-columns:1fr}.moduleHead,.hero{align-items:flex-start;gap:15px;flex-direction:column}header{padding:0 15px}.content{padding:15px}.topActions .iconBtn{display:none}}
/* Warm cream and gold dashboard theme */
body{background:#fbf8f0;color:#17233f}
.app{background:#fbf8f0;color:#17233f}
.sidebar{background:#fffdf8;border-color:#eee5d3;box-shadow:4px 0 16px #5c430b08}
.brand{padding:0 6px 18px;gap:9px}.brand .logo{background:transparent;color:#bf8616;font-size:29px;width:34px}.brand b{font-family:Georgia,serif;font-size:18px;font-weight:500;color:#17233f;white-space:nowrap}.goldPill{margin-left:auto;background:#bf8b1e;color:#fff;padding:4px 8px;border-radius:6px;font-size:10px;font-weight:800}
.profileCard{display:flex;align-items:center;gap:10px;padding:11px;margin:0 0 14px;border:1px solid #f0e8d9;border-radius:12px;background:#fff}.profileAvatar{width:42px;height:42px;border-radius:50%;background:#f5e5c2;color:#98680b;display:grid;place-items:center;font-weight:800}.profileCard div:nth-child(2){flex:1}.profileCard b,.profileCard small{display:block}.profileCard b{font-size:12px}.profileCard small{font-size:10px;color:#9b8a6b;margin-top:3px}.profileCard>span{font-size:12px;color:#a38c60}
.workspace{color:#a49370;border:0;padding:5px 10px;margin:0 0 5px;font-size:9px;letter-spacing:1.2px}
nav button{color:#334055;padding:9px 11px;border-radius:9px;font-size:13px}nav button i{width:19px;font-style:normal;font-size:16px;text-align:center;color:#8a6a2a}nav button:hover{background:#fbf3df;color:#73510d}nav button.active,.dark nav button.active{background:#faedc9;color:#6b4a0a}.navGroup{color:#a49270;margin:15px 11px 5px}.offline{background:#f9f4e9;border-color:#eee2c9;color:#536049}.offline small{color:#988768}
main{margin-left:248px}header{height:54px;background:#fffdf8;border-color:#eee5d3;padding:0 24px}.topbarBrand{position:absolute;left:50%;transform:translateX(-50%);font-family:Georgia,serif;font-size:19px;color:#17233f}.topbarBrand span{font-weight:400}.breadcrumb{font-size:14px}.globalSearch{background:#fff;border-color:#eee5d3}.iconBtn,.ghost{border-color:#eee5d3;background:#fff;color:#17233f}.avatar{background:#263c66}
.content{padding:14px 18px 22px;max-width:1600px}.card{background:#fff;border:1px solid #f0e9dc;border-radius:13px;box-shadow:0 2px 8px #5d47100a;padding:15px;margin-bottom:12px}.card h2{color:#17233f;font-size:14px}.balanceHero{height:106px;display:flex;align-items:center;justify-content:space-between;background:linear-gradient(105deg,#fff 0%,#fffdf8 68%,#f9edcf 100%);padding:16px 24px;overflow:hidden}.balanceHero strong{display:block;font:500 38px Georgia,serif;color:#17233f;letter-spacing:1px;margin:3px 0}.balanceHero small{font-size:10px;color:#80745e}.balanceHero small i{display:inline-block;width:7px;height:7px;background:#38a66b;border-radius:50%;margin-right:5px}.balanceOrnament{font:italic 42px Georgia,serif;color:#c59a43;opacity:.14;letter-spacing:7px}.balanceHeroActions{display:flex;align-items:center;gap:18px}.eyebrow{color:#8c7342;letter-spacing:1.1px;font-size:9px}.homeStats{grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-bottom:10px}.homeStats .card{min-height:72px;position:relative;margin:0;padding:12px 14px 10px 58px}.homeStats .card>span{color:#26334a;font-size:11px}.homeStats .card strong{font:500 22px Georgia,serif;color:#17233f;margin:3px 0}.homeStats .card small{font-size:9px;color:#988a70}.statIcon{position:absolute;left:13px;top:14px;width:34px;height:34px;border-radius:50%;display:grid;place-items:center;font-style:normal;font-size:20px;background:#faf0d9;color:#ae7b17}.incomeIcon{background:#edf5ed;color:#4b8e62}.expenseIcon{background:#e3f3ef;color:#168d80}.balanceIcon{background:#fdf0d9;color:#bd891c}
.chartCard{padding:14px 15px 11px;margin-bottom:10px}.chartCard .cardHead{margin-bottom:8px}.chartCard .cardHead small{display:block;color:#988a70;font-size:10px;margin-top:4px}.chartBadge{border:1px solid #f0e4ca;border-radius:8px;padding:6px 10px;color:#73510d;font-size:12px}.chart{height:120px;padding:8px 12px 0;gap:15px;position:relative;align-items:end;background:repeating-linear-gradient(to bottom,transparent 0,transparent 37px,#f2eee5 38px)}.chartGrid{position:absolute;left:0;top:5px;bottom:18px;display:flex;flex-direction:column;justify-content:space-between;color:#9b927f;font-size:9px}.barColumn{height:100%;flex:1;display:flex;flex-direction:column;align-items:center;justify-content:end;gap:5px;z-index:1}.bar{width:100%;max-width:50px;min-height:3px;border-radius:8px 8px 2px 2px;background:linear-gradient(180deg,#e7b543,#d69a1c);box-shadow:0 2px 5px #c88b1918}.barColumn small{font-size:9px;color:#93866c}.grid2.homeGrid{grid-template-columns:1fr 1fr;gap:10px;margin-bottom:10px}.homeGrid>.card{padding:12px 14px;margin:0;min-width:0}.cardHead{margin-bottom:9px}.textButton{border:0;background:transparent;color:#554b3b;font-size:10px;white-space:nowrap}.categoryRow{display:grid;grid-template-columns:24px minmax(70px,1fr) 1.3fr 28px 70px;align-items:center;gap:7px;margin:9px 0;font-size:10px}.categoryRow>b{font-weight:500}.categoryIcon{width:21px;height:21px;border-radius:50%;background:#f8eccd;color:#ad7915;display:grid;place-items:center}.category1{background:#e1f3ee;color:#168b7d}.category2{background:#e7effa;color:#4281b7}.category3{background:#f0e8f7;color:#8055a8}.category4{background:#f2eee4;color:#8d8268}.categoryTrack{height:6px;background:#f2eee7;border-radius:8px;overflow:hidden}.categoryTrack i{height:100%;display:block;background:#d6a12f;border-radius:8px}.categoryRow small{text-align:right;color:#6d6658}.categoryRow strong{text-align:right;font-weight:500}.goal{margin:10px 0}.goal>div:first-child b{font-size:11px;font-weight:500}.goal span,.goal small{color:#988a70;font-size:9px}.goal .progress{height:6px;margin:6px 0}.progress{background:#f1eee7}.progress i{background:linear-gradient(90deg,#e5b13d,#cc921c)}.tx{padding:8px 0;border-color:#f1ece3;gap:9px}.txIcon{width:27px;height:27px;border-radius:50%;background:#faf0d9;color:#ad7915}.txMain b{font-size:10px;font-weight:600}.txMain small{font-size:9px;color:#988a70}.tx strong{font-size:10px}.alertsCard{background:#fffdf9}.alertRow{display:flex;align-items:center;gap:9px;padding:9px 0;border-top:1px solid #f2ede5}.alertRow>span{width:27px;height:27px;border-radius:50%;display:grid;place-items:center;background:#edf5ed;color:#4b8e62}.alertRow b,.alertRow small{display:block}.alertRow b{font-size:10px;font-weight:600}.alertRow small{font-size:9px;color:#93866c;margin-top:3px}.assistantBanner{width:100%;display:flex;align-items:center;gap:12px;text-align:left;border:1px solid #ecd8a5;border-radius:11px;background:linear-gradient(100deg,#faedca,#f3dca4);color:#59420f;padding:9px 16px;margin:1px 0 0}.assistantBanner>span{font-size:22px;color:#bd8815}.assistantBanner div{flex:1}.assistantBanner b,.assistantBanner small{display:block}.assistantBanner b{font-size:13px}.assistantBanner small{font-size:10px;color:#78643a}.assistantBanner>strong{font-size:22px}.empty{padding:18px;color:#93866c;font-size:11px}.primary{background:#c28c1d;color:#fff}.aiCard{background:#fffdf8!important;color:#17233f}.aiCard p{color:#777}.dark .card,.dark header,.dark .sidebar{background:#fffdf8;color:#17233f}
.budgetPeriod{display:block;color:#988a70;font-size:10px;margin-top:4px}.resultCount{font-size:11px;color:#988a70;margin:0 0 5px}.budgetFilters{max-width:440px}.budgetFilters select{background:#fff;border:1px solid #eee5d3;border-radius:8px;color:#17233f;padding:9px 12px}
@media(max-width:1000px){.sidebar{width:210px}.profileCard{padding:8px}.content{padding:14px}.homeStats .card{padding-left:48px}.grid2.homeGrid{grid-template-columns:1fr 1fr}}
@media(max-width:700px){.sidebar{width:62px;padding:15px 7px}.brand{justify-content:center;padding:0 0 16px}.brand b,.brand .goldPill,.profileCard,.workspace,.navGroup,.offline div{display:none}.sidebar nav button{justify-content:center;font-size:0;padding:10px 4px}.sidebar nav button i{font-size:18px}.offline{left:7px;right:7px;justify-content:center;padding:8px}.offline span{font-size:0}.offline span:after{content:'●';font-size:12px;color:#38a66b}main{margin-left:62px;width:calc(100% - 62px)}header{padding:0 12px}.topbarBrand{display:none}.globalSearch{display:none}.content{padding:10px}.balanceHero{padding:14px;height:auto;min-height:92px}.balanceHero strong{font-size:30px}.balanceOrnament{font-size:24px}.homeStats{grid-template-columns:1fr}.homeStats .card{min-height:66px}.grid2.homeGrid{grid-template-columns:1fr}.chart{height:100px}.categoryRow{grid-template-columns:24px minmax(60px,1fr) 1fr 24px 65px}}
.backupLabel{display:block;font-size:12px;font-weight:650;margin:15px 0}.backupLabel input{display:block;width:100%;margin-top:6px;padding:11px;border:1px solid #eee5d3;border-radius:8px;background:#fff;color:#17233f}
.profileCompact .card{padding:12px}.profileCompact .homeGrid{gap:6px}.profileCompact .stats{gap:6px}
`

export default App
