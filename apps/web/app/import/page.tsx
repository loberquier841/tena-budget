'imports'



import { auth } from "@/auth";
import { getLocalTransactions, getLocalBudgets, getLocalCategories, getLocalSavingGoals, type LocalTransaction, type LocalBudget, type LocalCategory, type LocalSavingGoal } from "@/sync/dexie";
import { createTransaction, createBudget, type Budget, type Category } from "@/budget/budget";
import { createSavingGoal } from "@/budget/savings";
import { Role, assertCan } from "@/permissions/permissions";
import { prepareCsvExport, prepareExcelExport, preparePdfExport, type ExportFilters, type CsvExportData, type ExcelExportData, type PdfExportData } from "@/core/export/export";
import { runFullPipeline, type MigrationState, type OriginalFile, type RecognizedData, type ImportReport } from '@tena/import-engine';

async function loadTransactions(familyId: string | undefined) {
  let txs: LocalTransaction[] = [];
  try {
    txs = await getLocalTransactions(familyId);
  } catch (e) {
    console.error("Erreur chargement transactions:", e);
  }
  return txs;
}

async function loadBudgets(familyId: string | undefined) {
  let budgs: LocalBudget[] = [];
  try {
    budgs = await getLocalBudgets(familyId);
  } catch (e) {
    console.error("Erreur chargement budgets:", e);
  }
  return budgs;
}

async function loadGoals(familyId: string | undefined) {
  let goals: LocalSavingGoal[] = [];
  try {
    goals = await getLocalSavingGoals(familyId);
  } catch (e) {
    console.error("Erreur chargement objectifs:", e);
  }
  return goals;
}

interface ImportResult {
  success: boolean;
  message: string;
  created: { transactions: number; budgets: number; categories: number; goals: number };
  errors: string[];
}

export default async function ImportPage() {
  const session = await auth();
  if (!session) return <main style={{ marginLeft: 260, padding: 24 }}><p>Non connecté - <a href="/login">Login</a></p></main>;

  const familyId = session.userId;
  const existingTx = await loadTransactions(familyId);
  const existingBudgets = await loadBudgets(familyId);
  const existingGoals = await loadGoals(familyId);

  const [files, setFiles] = React.useState<FileList | null>(null);
  const [step, setStep] = React.useState<1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11>(1);
  const [error, setError] = React.useState<string | null>(null);
  const [report, setReport] = React.useState<ImportReport | null>(null);
  const [isImporting, setIsImporting] = React.useState(false);

  const steps = [
    { n: 1, label: 'Sélection', desc: 'CSV + XLSX multi-feuilles' },
    { n: 2, label: 'Analyse', desc: 'CSV parsé nativement' },
    { n: 3, label: 'Détection', desc: 'Colonnes + confiance 0-100' },
    { n: 4, label: 'Résumé', desc: 'Catégories, budgets, dépenses' },
    { n: 5, label: 'Corrections', desc: 'Mapping corrigé' },
    { n: 6, label: 'Doublons', desc: 'Exact hash + likely' },
    { n: 7, label: 'Comparaison', desc: 'Côte à côte' },
    { n: 8, label: 'Prévisualisation', desc: 'Sélection à importer' },
    { n: 9, label: 'Validation', desc: 'Valider avant import' },
    { n: 10, label: 'Import', desc: 'Importer les données' },
    { n: 11, label: 'Rapport', desc: 'Rapport d\'import' },
  ];

  const handleFileChange = (e: React.ChangeEvent) => {
    const newFiles = Array.from(e.target.files || []);
    setFiles(newFiles);
  };

  const handleImport = async () => {
    if (!files || files.length === 0) {
      setError('Aucun fichier sélectionné');
      return;
    }

    setIsImporting(true);
    setError(null);
    setReport(null);
    setStep(1);

    try {
      // Convert files to the format expected by the import engine
      const originalFiles: OriginalFile[] = files.map(f => ({
        id: crypto.randomUUID(),
        name: f.name,
        mime: f.name.endsWith('.xlsx') || f.name.endsWith('.xls') ? 'xlsx' : f.name.endsWith('.csv') ? 'csv' : 'unknown',
        size: f.size,
        buffer: f.arrayBuffer(),
      }));

      // Run the full pipeline
      const result = await runFullPipeline(
        originalFiles,
        existingTx.map(tx => ({
          id: tx.id,
          amountCents: tx.amountCents,
          bookingDate: tx.bookingDate,
          label: tx.label,
          hashDedup: tx.hashDedup || crypto.randomUUID(),
        }))
      );

      const { state, duplicateGroups } = result;

      if (state.step < 10) {
        // Show intermediate step
        setStep(state.step);
        setError('Pipeline incomplet - vérifiez les étapes précédentes');
        return;
      }

      // Step 9: Validation - check if user validated
      if (!state.validated) {
        setError('Validation obligatoire avant import réel');
        setStep(9);
        return;
      }

      // Step 10: Import - persist data to Dexie
      const toCreate = state.toCreate; // PreviewData with transactions, budgets, categories, goals

      // Persist transactions
      let createdTx = 0;
      if (toCreate.transactions && toCreate.transactions.length > 0) {
        for (const tx of toCreate.transactions) {
          try {
            await createTransaction({
              familyId,
              amountCents: tx.amountCents,
              bookingDate: tx.bookingDate,
              label: tx.label,
              source: tx.source || 'manual',
              categoryId: tx.category || undefined,
              personId: tx.person || undefined,
              budgetId: undefined,
              notes: undefined,
              createdByUserId: session.userId,
            }, 'owner');
            createdTx++;
          } catch (e) {
            console.error('Erreur création transaction:', e);
          }
        }
      }

      // Persist budgets
      let createdBudgets = 0;
      if (toCreate.budgets && toCreate.budgets.length > 0) {
        for (const budget of toCreate.budgets) {
          try {
            await createBudget({
              familyId,
              type: budget.type || 'monthly',
              year: budget.year || new Date().getFullYear(),
              month: budget.month,
              categoryId: budget.category || undefined,
              personId: undefined,
              amountCents: budget.amountCents,
            }, 'owner');
            createdBudgets++;
          } catch (e) {
            console.error('Erreur création budget:', e);
          }
        }
      }

      // Persist goals
      let createdGoals = 0;
      if (toCreate.goals && toCreate.goals.length > 0) {
        for (const goal of toCreate.goals) {
          try {
            await createSavingGoal({
              familyId,
              personId: undefined,
              name: goal.name,
              targetCents: goal.targetCents || 0,
            }, 'owner');
            createdGoals++;
          } catch (e) {
            console.error('Erreur création objectif:', e);
          }
        }
      }

      // Step 11: Generate report
      const errors: { row: number; error: string }[] = [];
      // Check for any errors during import
      if (createdTx === 0 && toCreate.transactions && toCreate.transactions.length > 0) {
        errors.push({ row: 0, error: 'Aucune transaction importée - erreurs de validation' });
      }

      const importReport: ImportReport = {
        imported: {
          budgets: createdBudgets,
          categories: 0, // categories not persisted separately, included in budgets
          goals: createdGoals,
          persons: 0,
          transactions: createdTx,
        },
        ignored: { count: 0, items: [] },
        modified: { count: 0, items: [] },
        ambiguous: { count: state.data_ambiguous?.filter(a => a.status === 'pending').length || 0, columns: state.data_ambiguous?.filter(a => a.status === 'pending').map(a => a.column) || [] },
        duplicates: { count: Object.keys(state.duplicateDecisions || {}).length, groups: [] },
        errors: errors,
        attention: { count: state.data_recognized?.partialWarnings.length || 0, items: state.data_recognized?.partialWarnings || [] },
        isPartial: state.data_recognized?.isPartial || false,
        yearsImported: state.yearsSelected,
      };

      setReport(importReport);
      setStep(11);
    } catch (err: any) {
      console.error('Import error:', err);
      setError(err.message || 'Erreur lors de l\'import');
      setStep(1);
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <main style={{ marginLeft: 260, padding: 24, background: '#fafafa', minHeight: '100vh' }}>
      <h1 style={{ fontSize: 28 }}>📥 Import — Pipeline 11 étapes</h1>
      <p style={{ color: '#666' }}>Fichiers originaux read-only • XLSX multi-feuilles + CSV • Dates FR + EUR • Aucun import réel avant validation</p>

      <div style={{ marginTop: 16, display: 'flex', gap: 4, marginTop: 16, overflowX: 'auto', paddingBottom: 8 }}>
        {steps.map(s => (
          <div key={s.n} style={{
            flex: 1, minWidth: 90, padding: '8px 6px', borderRadius: 8, textAlign: 'center',
            background: s.n === step ? '#7C3AED' : s.n < step ? '#bbf7d0' : '#e5e7eb',
            color: s.n === step ? 'white' : s.n < step ? '#166534' : '#666',
            fontSize: 11, cursor: s.n < step ? 'pointer' : 'default',
            border: s.n === step ? '2px solid #7C3AED' : '1px solid transparent',
          }}>
            {s.n}
          </div>
        ))}

        {canGoBack && <button onClick={() => setStep((step - 1) as Step)} style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid #e5e7eb', background: 'white' }}>← Retour (sûr)</button>}
        {canGoNext && step < 11 && <button onClick={() => setStep((step + 1) as Step)} style={{ padding: '8px 16px', borderRadius: 8, border: 'none', background: '#7C3AED', color: 'white' }}>Suivant →</button>}
        {step === 11 && <button onClick={() => setStep(10) as Step} style={{ padding: '8px 16px', borderRadius: 8, border: '1px solid #e5e7eb', background: 'white' }}>Re-importer</button>}

        {step === 10 && !report && <span style={{ color: '#ef4444', fontSize: 12, padding: 8 }}>⚠ Validation requise avant import réel</span>}

        {report && (
          <div style={{ marginTop: 16, padding: 12, background: '#f0fdf4', borderRadius: 8, border: '1px solid #bbf7d0' }}>
            <h3>Rapport d'import</h3>
            <p>Importés : {report.imported.transactions} transactions, {report.imported.budgets} budgets, {report.imported.goals} objectifs</p>
            <p>Erreurs : {report.errors.length} lignes en erreur</p>
            <p>Doublons : {report.duplicates.count} groupes détectés</p>
            <p>Attention : {report.attention.count} avertissements</p>
          </div>
        )}

        {/* Étape 1 - Sélection */}
        {step === 1 && (
          <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
            <h2>1. Sélection — Fichiers originaux read-only</h2>
            <p style={{ fontSize: 12, color: '#666' }}>XLSX multi-feuilles (Sheet1, 2024, 2025...) + CSV • Buffer ArrayBuffer jamais muté • Plusieurs fichiers</p>
            <div style={{ border: '2px dashed #7C3AED', borderRadius: 12, padding: 24, textAlign: 'center', marginTop: 12 }}>
              <p>Glisser XLSX/CSV ici ou</p>
              <input type="file" multiple accept=".xlsx,.xls,.csv" onChange={handleFileChange} />
              <p style={{ fontSize: 11, color: '#888', marginTop: 8 }}>Fichiers: {files?.length > 0 ? files.map(f => f.name).join(', ') : 'aucun'}</p>
            </div>
            <p style={{ fontSize: 11, color: '#22c55e', marginTop: 8 }}>✓ file_original jamais muté • read-only ref</p>
          </div>
        )}

        {/* Étape 2 - Analyse */}
        {step === 2 && (
          <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
            <h2>2. Analyse — SheetJS worker</h2>
            <p style={{ fontSize: 12 }}>Fichiers analysés avec succès</p>
          </div>
        )}

        {/* Étape 3 - Détection */}
        {step === 3 && (
          <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
            <h2>3. Détection — Colonnes + confiance + EUR + dates FR</h2>
            <p style={{ fontSize: 12 }}>Détection en cours...</p>
          </div>
        )}

        {/* Étape 10 - Import */}
        {step === 10 && (
          <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
            <h2>10. Import — Importation des données</h2>
            <p>Importation en cours... Veuillez patienter.</p>
            <p>Création de {files?.length || 0} fichier(s) en cours...</p>
          </div>
        )}

        {/* Étape 11 - Rapport */}
        {step === 11 && report && (
          <div style={{ background: 'white', padding: 20, borderRadius: 12, border: '1px solid #e5e7eb', marginTop: 16 }}>
            <h2>11. Rapport — Résultat de l'import</h2>
            <p>Successfully imported:</p>
            <ul>
              <li>{report.imported.transactions} transactions</li>
              <li>{report.imported.budgets} budgets</li>
              <li>{report.imported.goals} objectifs d'épargne</li>
            </ul>
            <p>Errors: {report.errors.length}</p>
            <button onClick={() => setStep(1)} style={{ marginTop: 16, padding: '8px 16px', borderRadius: 8, border: '1px solid #e5e7eb', background: 'white' }}>Nouvel import</button>
          </div>
        )}
      </div>
    </main>
  );
}
