/* eslint-disable @typescript-eslint/no-explicit-any */
'use client';

import { useEffect, useState, useCallback } from 'react';

import { navigate } from 'next/navigation';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { auth } from '@/auth';
import {
  getLocalUserProfile,
  getLocalTransactions,
  getLocalBudgets,
  getLocalSavingGoals,
  db,
  type LocalTransaction,
  type LocalBudget,
  type LocalSavingGoal,
} from '@tena/core/sync/dexie';
import {
  filterValidTransactions,
  getSpendingByCategory,
  getMonthlyEvolution,
  getBudgetVsSpent,
  getSavingsStats,
  type StatsFilters,
} from '@tena/core/analytics/stats';
import { centsToEurosDisplay } from '@tena/core/analytics/charts';
import { type UserProfile, type DashboardCardId } from '@tena/core';
import { APP_NAME, fromCents, toCents } from '@tena/shared';

// Couleurs de marque TENΛ Budget
const COLOR_PRIMARY = '#7C3AED';
const COLOR_DARK = '#0A0A0B';
const COLOR_SUCCESS = '#22c55e';
const COLOR_ERROR = '#ef4444';
const COLOR_BORDER = '#e5e7eb';
const COLOR_BG = '#fafafa';
const COLOR_CARD_BG = '#ffffff';
const COLOR_TEXT_MUTED = '#666';
const COLOR_TEXT_DIM = '#886';

const CATEGORY_COLORS: Record<string, string> = {
  Courses: '#7C3AED',
  Logement: '#22c55e',
  Transport: '#f59e0b',
  Loisirs: '#ef4444',
};

function categoryColor(name: string): string {
  return CATEGORY_COLORS[name] || COLOR_PRIMARY;
}

function fmtEuros(cents: number): string {
  return centsToEurosDisplay(cents);
}

function fmtDate(iso: string | Date): string {
  const d = typeof iso === 'string' ? new Date(iso) : iso;
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

// Détecte un familyId depuis les tables Dexie non chiffrées (familyId n'est pas dans encryptedFields)
async function detectFamilyId(): Promise<string | undefined> {
  try {
    const [txs, budgs, goals] = await Promise.all([
      db.transactions.toArray(),
      db.budgets.toArray(),
      db.savingGoals.toArray(),
    ]);
    const ids = new Set<string>();
    for (const t of txs) if (t.familyId) ids.add(t.familyId);
    for (const b of budgs) if (b.familyId) ids.add(b.familyId);
    for (const g of goals) if (g.familyId) ids.add(g.familyId);
    return ids.values().next().value;
  } catch {
    return undefined;
  }
}

interface StatCardProps {
  title: string;
  value: string;
  sub: string;
  color?: string;
  delta?: string;
}

function StatCard({ title, value, sub, color, delta }: StatCardProps) {
  return (
    <div
      style={{{
        background: COLOR_CARD_BG,
        padding: 16,
        borderRadius: 12,
        border: `1px solid ${COLOR_BORDER}`,
        display: 'flex',
        flexDirection: 'column',
        gap: 6,
      }}}
    >
      <p style={{ fontSize: 11, color: COLOR_TEXT_MUTED, margin: 0, letterSpacing: '0.05em', textTransform: 'uppercase' }}>{title}</p>
      <p style={{ fontSize: 26, fontWeight: 700, color: color || '#111', margin: 0 }}>{value}</p>
      {delta && (
        <p
          style={{ fontSize: 11, color: delta.startsWith('-') ? COLOR_ERROR : COLOR_SUCCESS, margin: 0, fontWeight: 600 }}
        >
          {delta}
        </p>
      )}
      <p style={{ fontSize: 10, color: COLOR_TEXT_DIM, margin: 0 }}>{sub}</p>
    </div>
  );
}

interface EmptyStateProps {
  title: string;
  description: string;
  actionLabel: string;
  actionHref: string;
  icon?: string;
}

function EmptyState({ title, description, actionLabel, actionHref, icon = '📭' }: EmptyStateProps) {
  return (
    <div
      style={{{
        background: COLOR_CARD_BG,
        border: `1px solid ${COLOR_BORDER}`,
        borderRadius: 12,
        padding: 32,
        textAlign: 'center',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 12,
      }}}
    >
      <span style={{ fontSize: 32 }}>{icon}</span>
      <h3 style={{ fontSize: 16, margin: 0, color: '#111' }}>{title}</h3>
      <p style={{ fontSize: 13, color: COLOR_TEXT_MUTED, margin: 0, maxWidth: 300, lineHeight: 1.5 }}>{description}</p>
      <Link
        href={actionHref}
        style={{{
          background: COLOR_PRIMARY,
          color: 'white',
          padding: '10px 18px',
          borderRadius: 8,
          textDecoration: 'none',
          fontSize: 13,
          fontWeight: 600,
          border: 'none',
          cursor: 'pointer',
        }}}
      >
        {actionLabel}
      </Link>
    </div>
  );
}

interface CategoryCardProps {
  name: string;
  totalCents: number;
  count: number;
  color: string;
  totalSpentCents: number;
}

function CategoryCard({ name, totalCents, count, color, totalSpentCents }: CategoryCardProps) {
  const pct = totalSpentCents ? Math.floor((totalCents * 100) / totalSpentCents) : 0;
  return (
    <div
      style={{{
        background: COLOR_CARD_BG,
        border: `1px solid ${COLOR_BORDER}`,
        borderRadius: 12,
        padding: 14,
        display: 'flex',
        alignItems: 'center',
        gap: 12,
      }}}
    >
      <div style={{ width: 10, height: 10, background: color, borderRadius: 2 }}></div>
      <span style={{ flex: 1, fontSize: 13, color: '#111' }}>{name}</span>
      <span style={{ fontSize: 13, fontWeight: 600, color: '#111' }}}{fmtEuros(totalCents)}</span>
      <span style={{ fontSize: 11, color: COLOR_TEXT_DIM }}>{count} tx</span>
      <div style={{ width: 70, height: 6, background: '#e5e7eb', borderRadius: 3, overflow: 'hidden' }}>
        <div style={{ width: `${Math.min(pct, 100)}%`, height: '100%', background: color, borderRadius: 3 }}></div>
      </div>
      <span style={{ fontSize: 11, color: COLOR_TEXT_DIM }}>{pct}%</span>
    </div>
  );
}

interface BudgetRowProps {
  id: string;
  type: string;
  year: number;
  month?: number;
  categoryName?: string;
  personName?: string;
  isGlobal: boolean;
  budgetedCents: number;
  spentCents: number;
  remainingCents: number;
}

function BudgetRow({
  id,
  type,
  year,
  month,
  categoryName,
  personName,
  isGlobal,
  budgetedCents,
  spentCents,
  remainingCents,
}: BudgetRowProps) {
  const pct = budgetedCents ? Math.floor((spentCents * 100) / budgetedCents) : 0;
  const overBudget = spentCents > budgetedCents;
  return (
    <tr key={id} style={{ borderTop: '1px solid #f3f4f6' }}>
      <td style={{ padding: 12, fontSize: 12 }}>
        <span
          style={{{
            background: type === 'annual' ? '#ddd6fe' : '#fef3c7',
            color: type === 'annual' ? '#5b21b6' : '#92400e',
            padding: '2px 8px',
            borderRadius: 12,
            fontSize: 10,
            fontWeight: 600,
          }}}
        >
          {type === 'annual' ? 'Annuel' : 'Mensuel'}
        </span>
      </td>
      <td style={{ padding: 12, fontSize: 12 }}}{year}{month ? `-${String(month).padStart(2, '0')}` : ''}</td>
      <td style={{ padding: 12, fontSize: 12 }}}{categoryName || '—'}</td>
      <td style={{ padding: 12, fontSize: 12 }}}{personName || (isGlobal ? 'Famille (global)' : '—')}</td>
      <td style={{ padding: 12, fontSize: 12 }}><strong>{fmtEuros(budgetedCents)}</strong></td>
      <td style={{ padding: 12, fontSize: 12 }}><strong style={{ color: overBudget ? COLOR_ERROR : '#111' }}}{fmtEuros(spentCents)}</strong></td>
      <td style={{ padding: 12, fontSize: 12 }}><strong style={{ color: remainingCents < 0 ? COLOR_ERROR : '#111' }}}{fmtEuros(remainingCents)}</strong></td>
      <td style={{ padding: 12 }}>
        <div style={{ width: '100%', height: 6, background: '#e5e7eb', borderRadius: 3, overflow: 'hidden' }}>
          <div
            style={{{
              width: `${Math.min(Math.max(pct, 0), 100)}%`,
              height: '100%',
              background: overBudget ? COLOR_ERROR : pct > 80 ? '#f59e0b' : COLOR_SUCCESS,
              borderRadius: 3,
            }}}
          ></div>
        </div>
      </td>
    </tr>
  );
}

interface GoalCardProps {
  id: string;
  name: string;
  personName?: string;
  targetCents: number;
  currentCents: number;
  remainingCents: number;
  percentInt: number;
  isExceeded: boolean;
}

function GoalCard({
  id,
  name,
  personName,
  targetCents,
  currentCents,
  remainingCents,
  percentInt,
  isExceeded,
}: GoalCardProps) {
  return (
    <div key={id} style={{{
      background: COLOR_CARD_BG,
      border: `1px solid ${COLOR_BORDER}`,
      borderRadius: 12,
      padding: 18,
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
    }}}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <h3 style={{ fontSize: 15, margin: 0, color: '#111' }}>{name}</h3>
        {isExceeded && (
          <span style={{ fontSize: 11, color: COLOR_SUCCESS, fontWeight: 700 }}>🎉 Dépassé !</span>
        )}
      </div>
      <p style={{ fontSize: 12, color: COLOR_TEXT_MUTED, margin: 0 }}>{personName ? `(${personName})` : '(Famille)'}</p>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, color: COLOR_TEXT_DIM }}>
        <span>{fmtEuros(currentCents)} / {fmtEuros(targetCents)}</span>
        <span>{percentInt}%</span>
      </div>
      <div style={{ width: '100%', height: 8, background: '#e5e7eb', borderRadius: 4, overflow: 'hidden' }}>
        <div
          style={{{
            width: `${Math.min(percentInt, 100)}%`,
            height: '100%',
            background: isExceeded ? COLOR_SUCCESS : COLOR_PRIMARY,
            borderRadius: 4,
          }}}
        ></div>
      </div>
      <p style={{ fontSize: 11, color: COLOR_TEXT_DIM, margin: 0 }}>
        Restant : {fmtEuros(remainingCents)}
      </p>
    </div>
  );
}

interface TransactionRowProps {
  tx: LocalTransaction;
  categoryName?: string;
  personName?: string;
}

function TransactionRow({ tx, categoryName, personName }: TransactionRowProps) {
  const isExpense = tx.amountCents > 0;
  return (
    <tr key={tx.id} style={{ borderTop: '1px solid #f3f4f6', opacity: tx.isDeleted ? 0.5 : 1 }}>
      <td style={{ padding: 10, fontSize: 12 }}}{fmtDate(tx.bookingDate)}</td>
      <td style={{ padding: 10, fontSize: 12 }}}{tx.label}</td>
      <td style={{ padding: 10, fontSize: 12 }}}{categoryName || '—'}</td>
      <td style={{ padding: 10, fontSize: 12 }}}{personName || '—'}</td>
      <td style={{ padding: 10, fontSize: 12 }}>
        <strong style={{ color: isExpense ? COLOR_ERROR : '#111' }}>{fmtEuros(tx.amountCents)}</strong>
      </td>
      <td style={{ padding: 10, fontSize: 11 }}>
        <span
          style={{{
            background: '#f3f4f6',
            padding: '1px 6px',
            borderRadius: 6,
            fontSize: 10,
            textTransform: 'uppercase',
          }}}
        >
          {tx.source}
        </span>
      </td>
      <td style={{ padding: 10 }}>
        <Link
          href="/transactions"
          style={{{
            fontSize: 11,
            padding: '4px 8px',
            borderRadius: 6,
            border: `1px solid ${COLOR_BORDER}`,
            textDecoration: 'none',
            color: COLOR_PRIMARY,
          }}}
        >
          Voir
        </Link>
      </td>
    </tr>
  );
}

interface DashboardViewProps {
  userId: string;
}

interface DashboardCardId {
  spending: boolean;
  goals: boolean;
  'recent-transactions': boolean;
}

interface UserProfile {
  answers: {
    householdMode: string;
  };
  dashboard: {
    visibleCards: DashboardCardId;
  };
}

export default function DashboardView({ userId }: DashboardViewProps) {
  const pathname = usePathname();

  // Check authentication on mount
  useEffect(() => {
    (async () => {
      const session = await auth();
      if (!session || !session.userId) {
        navigate('/login');
        return;
      }
    })();
  }, []);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [familyId, setFamilyId] = useState<string | undefined>(undefined);
  const [transactions, setTransactions] = useState<LocalTransaction[]>([]);
  const [budgets, setBudgets] = useState<LocalBudget[]>([]);
  const [goals, setGoals] = useState<LocalSavingGoal[]>([]);

  const visibleCards: DashboardCardId[] = profile?.dashboard.visibleCards ?? [
    'spending',
    'goals',
    'recent-transactions',
  ];

  const householdMode = profile?.answers.householdMode || 'individual';

  const [stats, setStats] = useState<{
    budgetedCents: number;
    spentCents: number;
    remainingCents: number;
    byCategory: { name: string; totalCents: number; count: number; color: string }[];
    monthly: { label: string; totalCents: number }[];
    budgetsWithUsage: { id: string; type: string; year: number; month?: number; categoryName?: string; personName?: string; isGlobal: boolean; budgetedCents: number; spentCents: number; remainingCents: number }[];
    goalsStats: { id: string; name: string; personName?: string; targetCents: number; currentCents: number; remainingCents: number; percentInt: number; isExceeded: boolean }[];
    recentTransactions: { id: string; date: string; label: string; categoryName?: string; personName?: string; amountCents: number; source: string; isDeleted: boolean }[];
  } | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const userProfile = await getLocalUserProfile();
      setProfile(userProfile ?? null);

      const fid = await detectFamilyId();
      setFamilyId(fid);

      if (!fid) {
        setLoading(false);
        return;
      }

      const [txs, budgs, gls] = await Promise.all([
        getLocalTransactions(fid),
        getLocalBudgets(fid),
        getLocalSavingGoals(fid),
      ]);

      setTransactions(txs);
      setBudgets(budgs);
      setGoals(gls);

      const filters: StatsFilters = { familyId: fid };
      const validTx = filterValidTransactions(txs, filters);

      const spentCents = validTx.reduce((sum, t) => sum + t.amountCents, 0);
      const budgetedCents = budgs.reduce((sum, b) => sum + b.amountCents, 0);
      const remainingCents = budgetedCents - spentCents;

      const catsRaw = await db.categories.toArray();
      const categories = catsRaw.map((c: any) => ({
        id: c.id,
        familyId: c.familyId,
        name: c.name,
        parentId: c.parentId ?? null,
        isArchived: c.isArchived ?? false,
        createdAt: c.createdAt ? new Date(c.createdAt) : new Date(),
      }));
      const byCategoryRaw = getSpendingByCategory(txs, categories, filters);
      const totalSpent = byCategoryRaw.reduce((s, c) => s + c.totalCents, 0);
      const byCategory = byCategoryRaw.map((c) => ({
        name: c.categoryName,
        totalCents: c.totalCents,
        count: c.count,
        color: categoryColor(c.categoryName),
      }));

      const monthlyRaw = getMonthlyEvolution(txs, filters);
      const monthly = monthlyRaw.map((m) => ({
        label: `${m.year}-${String(m.month).padStart(2, '0')}`,
        totalCents: m.totalCents,
      }));

      const budgetsVsSpent = getBudgetVsSpent(budgs, txs, { ...filters, year: new Date().getFullYear() });
      const personsRaw = await db.persons.toArray();
      const personMap = new Map<string, string>();
      for (const p of personsRaw) personMap.set(p.id, p.name);
      const categoryMap = new Map<string, string>();
      for (const c of categories) categoryMap.set(c.id, c.name);

      const budgetsWithUsage = budgetsVsSpent.map((b) => ({
        id: b.budgetId,
        type: b.type,
        year: b.year,
        month: b.month,
        categoryName: b.categoryId ? categoryMap.get(b.categoryId) : undefined,
        personName: b.personId ? personMap.get(b.personId) : undefined,
        isGlobal: !b.personId,
        budgetedCents: b.budgetedCents,
        spentCents: b.spentCents,
        remainingCents: b.remainingCents,
      }));

      const goalsStats = getSavingsStats(gls, filters).map((g) => ({
        id: g.goalId,
        name: g.name,
        personName: g.personId ? personMap.get(g.personId) : undefined,
        targetCents: g.targetCents,
        currentCents: g.currentCents,
        remainingCents: g.remainingCents,
        percentInt: g.percentInt,
        isExceeded: g.isExceeded,
      }));

      const recentTx = [...validTx]
        .sort((a, b) => b.bookingDate.getTime() - a.bookingDate.getTime())
        .slice(0, 10)
        .map((t) => ({
          id: t.id,
          date: t.bookingDate.toISOString(),
          label: t.label,
          categoryName: t.categoryId ? categoryMap.get(t.categoryId) : undefined,
          personName: t.personId ? personMap.get(t.personId) : undefined,
          amountCents: t.amountCents,
          source: t.source,
          isDeleted: t.isDeleted,
        }));

      setStats({
        budgetedCents,
        spentCents,
        remainingCents,
        byCategory,
        monthly,
        budgetsWithUsage,
        goalsStats,
        recentTransactions: recentTx,
      });
    } catch (err: any) {
      setError(err.message || 'Erreur lors du chargement des données');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadData();
  }, [loadData]);

  if (!profile) {
    return (
      <main style={{ marginLeft: 260, padding: 24, background: COLOR_BG, minHeight: '100vh' }}>
        <Header />
        <div style={{ maxWidth: 1200, margin: '0 auto' }}>
          <EmptyState
            title="Profil non configuré"
            description="Vous n'avez pas encore complété l'onboarding. Le tableau de bord sera personnalisé selon vos réponses."
            actionLabel="Commencer l'onboarding"
            actionHref="/onboarding"
            icon="📝"
          />
        </div>
      </main>
    );
  }

  if (loading) {
    return (
      <main style={{ marginLeft: 260, padding: 24, background: COLOR_BG, minHeight: '100vh' }}>
        <Header />
        <div style={{ maxWidth: 1200, margin: '0 auto' }}>
          <div
            style={{{
              background: COLOR_CARD_BG,
              border: `1px solid ${COLOR_BORDER}`,
              borderRadius: 12,
              padding: 48,
              textAlign: 'center',
              color: COLOR_TEXT_MUTED,
            }}}
          >
            Chargement du tableau de bord…
          </div>
        </div>
      </main>
    );
  }

  if (error) {
    return (
      <main style={{ marginLeft: 260, padding: 24, background: COLOR_BG, minHeight: '100vh' }}>
        <Header />
        <div style={{ maxWidth: 1200, margin: '0 auto' }}>
          <div
            style={{{
              background: '#fef2f2',
              border: `1px solid ${COLOR_ERROR}`,
              borderRadius: 12,
              padding: 24,
              color: '#991b1b',
            }}}
          >
            <p style={{ fontWeight: 600, margin: 0, marginBottom: 8 }}>{error}</p>
            <button
              onClick={loadData}
              style={{{
                background: COLOR_PRIMARY,
                color: 'white',
                border: 'none',
                padding: '8px 16px',
                borderRadius: 6,
                fontSize: 13,
                cursor: 'pointer',
              }}}
            >
              Réessayer
            </button>
          </div>
        </div>
      </main>
    );
  }

  if (!familyId) {
    return (
      <main style={{ marginLeft: 260, padding: 24, background: COLOR_BG, minHeight: '100vh' }}>
        <Header />
        <div style={{ maxWidth: 1200, margin: '0 auto' }}>
          <EmptyState
            title="Aucune donnée trouvée"
            description="Aucune transaction, budget ou objectif n'a encore été enregistré pour votre profil. Commencez par importer ou ajouter une transaction."
            actionLabel="Ajouter une transaction"
            actionHref="/transactions"
            icon="📭"
          />
          <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 12 }}>
            <EmptyState
              title="Créer un budget"
              description="Définissez vos objectifs de dépenses par catégorie et période."
              actionLabel="Voir les budgets"
              actionHref="/budgets"
              icon="💰"
            />
            <EmptyState
              title="Définir un objectif"
              description="Fixez une cible d'épargne et suivez votre progression."
              actionLabel="Voir les objectifs"
              actionHref="/objectifs"
              icon="🎯"
            />
          </div>
        </div>
      </main>
    );
  }

  const s = stats!;
  const cardsGridStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: 'repeat(3, 1fr)',
    gap: 12,
    marginBottom: 20,
  };
  if (window.innerWidth < 768) cardsGridStyle.gridTemplateColumns = '1fr';

  return (
    <main style={{ marginLeft: 260, padding: 24, background: COLOR_BG, minHeight: '100vh' }}>
      <Header />
      <div style={{ maxWidth: 1200, margin: '0 auto' }}>
        {/* En-tête de page */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
          <div>
            <h1
              style={{{
                fontSize: 24,
                fontWeight: 700,
                color: '#111',
                margin: 0,
                marginBottom: 4,
                letterSpacing: '-0.02em',
              }}}
            >
              Tableau de bord
            </h1>
            <p style={{ fontSize: 13, color: COLOR_TEXT_MUTED, margin: 0 }}>
              {APP_NAME} • {profile?.answers.householdMode || '—'}
            </p>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <Link
              href="/transactions"
              style={{{
                background: COLOR_CARD_BG,
                border: `1px solid ${COLOR_BORDER}`,
                color: '#111',
                padding: '8px 14px',
                borderRadius: 8,
                textDecoration: 'none',
                fontSize: 13,
              }}}
            >
              Transactions
            </Link>
            <Link
              href="/budgets"
              style={{{
                background: COLOR_CARD_BG,
                border: `1px solid ${COLOR_BORDER}`,
                color: '#111',
                padding: '8px 14px',
                borderRadius: 8,
                textDecoration: 'none',
                fontSize: 13,
              }}}
            >
              Budgets
            </Link>
            <Link
              href="/objectifs"
              style={{{
                background: COLOR_CARD_BG,
                border: `1px solid ${COLOR_BORDER}`,
                color: '#111',
                padding: '8px 14px',
                borderRadius: 8,
                textDecoration: 'none',
                fontSize: 13,
              }}}
            >
              Objectifs
            </Link>
          </div>
        </div>

        {/* Cartes de synthèse */}
        {visibleCards.includes('spending') && (
          <div style={cardsGridStyle}>
            <StatCard
              title="Budget prévu"
              value={fmtEuros(s.budgetedCents)}
              sub={`${s.budgetedCents}c • Int centimes`}
              color={COLOR_PRIMARY}
            />
            <StatCard
              title="Dépensé"
              value={fmtEuros(s.spentCents)}
              sub={`${s.spentCents}c • isDeleted exclu`}
              color={COLOR_ERROR}
              delta={s.spentCents > 0 ? `-${fmtEuros(s.spentCents)} vs prévu` : undefined}
            />
            <StatCard
              title="Restant"
              value={fmtEuros(s.remainingCents)}
              sub={s.remainingCents >= 0 ? 'Sous budget' : 'Dépassement'}
              color={s.remainingCents >= 0 ? COLOR_SUCCESS : COLOR_ERROR}
              delta={s.remainingCents >= 0 ? `+${fmtEuros(s.remainingCents)}` : `${fmtEuros(s.remainingCents)}`}
            />
          </div>
        )}

        {/* Graphiques : dépenses par catégorie */}
        {visibleCards.includes('spending') && s.byCategory.length > 0 && (
          <div
            style={{{
              background: COLOR_CARD_BG,
              border: `1px solid ${COLOR_BORDER}`,
              borderRadius: 12,
              padding: 18,
              marginBottom: 20,
            }}}
          >
            <h2 style={{ fontSize: 15, margin: 0, marginBottom: 14, color: '#111' }}>Dépenses par catégorie</h2>
            <div
              style={{{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
                gap: 10,
              }}}
            >
              {s.byCategory.map((c) => (
                <CategoryCard
                  key={c.name}
                  name={c.name}
                  totalCents={c.totalCents}
                  count={c.count}
                  color={c.color}
                  totalSpentCents={s.spentCents}
                />
              ))}
            </div>
          </div>
        )}

        {/* Graphique : évolution mensuelle */}
        {visibleCards.includes('spending') && s.monthly.length > 0 && (
          <div
            style={{{
              background: COLOR_CARD_BG,
              border: `1px solid ${COLOR_BORDER}`,
              borderRadius: 12,
              padding: 18,
              marginBottom: 20,
            }}}
          >
            <h2 style={{ fontSize: 15, margin: 0, marginBottom: 14, color: '#111' }}>Évolution mensuelle des dépenses</h2>
            <div style={{ height: 120 }}>
              <div
                style={{{
                  display: 'flex',
                  alignItems: 'flex-end',
                  gap: 10,
                  height: 100,
                  paddingBottom: 8,
                }}}
              >
                {s.monthly.map((m) => {
                  const max = Math.max(...s.monthly.map((x) => x.totalCents));
                  const pct = max ? Math.floor((m.totalCents / max) * 100) : 0;
                  return (
                    <div key={m.label} style={{{
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      flex: 1,
                    }}}>
                      <div
        style={{{
                          width: '100%',
                          background: COLOR_PRIMARY,
                          height: `${Math.max(pct, 8)}%`,
                          minHeight: 8,
                          borderRadius: '4px 4px 0 0',
                        }}}
                      ></div>
                      <span style={{ fontSize: 11, marginTop: 6, color: COLOR_TEXT_MUTED }}>{m.label.slice(5)}</span>
                      <span style={{ fontSize: 10, color: COLOR_TEXT_DIM }}>{fmtEuros(m.totalCents)}</span>
                    </div>
                  );
                })}
              </div>
            </div>
            <p style={{ fontSize: 10, color: COLOR_TEXT_DIM, margin: 8, marginTop: 0 }}
              >getMonthlyEvolution() • Int centimes • isDeleted exclu</p>
          </div>
        )}

        {/* Section Budgets */}
        {(visibleCards.includes('spending') || visibleCards.includes('goals')) && s.budgetsWithUsage.length > 0 && (
          <div
            style={{{
              background: COLOR_CARD_BG,
              border: `1px solid ${COLOR_BORDER}`,
              borderRadius: 12,
              padding: 18,
              marginBottom: 20,
            }}}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h2 style={{ fontSize: 15, margin: 0, color: '#111' }}>Budgets — utilisation réelle</h2>
              <Link
                href="/budgets"
                style={{{
                  fontSize: 12,
                  color: COLOR_PRIMARY,
                  textDecoration: 'none',
                  fontWeight: 600,
                }}}
              >
                Voir tous →
              </Link>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
                <thead>
                  <tr style={{ textAlign: 'left', color: COLOR_TEXT_MUTED, marginBottom: 8 }}>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Type</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Période</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Catégorie</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Personne</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'right' }}>Prévu</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'right' }}>Dépensé</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'right' }}>Restant</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'right' }}>Utilisation</th>
                  </tr>
                </thead>
                <tbody>
                  {s.budgetsWithUsage.map((b) => (
                    <BudgetRow key={b.id} {...b} />
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Section Objectifs */}
        {visibleCards.includes('goals') && s.goalsStats.length > 0 && (
          <div
            style={{{
              background: COLOR_CARD_BG,
              border: `1px solid ${COLOR_BORDER}`,
              borderRadius: 12,
              padding: 18,
              marginBottom: 20,
            }}}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h2 style={{ fontSize: 15, margin: 0, color: '#111' }}>Objectifs d'épargne</h2>
              <Link
                href="/objectifs"
                style={{{
                  fontSize: 12,
                  color: COLOR_PRIMARY,
                  textDecoration: 'none',
                  fontWeight: 600,
                }}}
              >
                Voir tous →
              </Link>
            </div>
            <div
              style={{{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
                gap: 12,
              }}}
            >
              {s.goalsStats.map((g) => (
                <GoalCard key={g.id} {...g} />
              ))}
            </div>
          </div>
        )}

        {/* Section Transactions récentes */}
        {(visibleCards.includes('spending') || visibleCards.includes('recent-transactions')) && s.recentTransactions.length > 0 && (
          <div
            style={{{
              background: COLOR_CARD_BG,
              border: `1px solid ${COLOR_BORDER}`,
              borderRadius: 12,
              padding: 18,
            }}}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
              <h2 style={{ fontSize: 15, margin: 0, color: '#111' }}>Transactions récentes</h2>
              <Link
                href="/transactions"
                style={{{
                  fontSize: 12,
                  color: COLOR_PRIMARY,
                  textDecoration: 'none',
                  fontWeight: 600,
                }}}
              >
                Voir toutes →
              </Link>
            </div>
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 12 }}>
                <thead>
                  <tr style={{ textAlign: 'left', color: COLOR_TEXT_MUTED }}>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Date</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Libellé</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Catégorie</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Personne</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'right' }}>Montant</th>
                    <th style={{ padding: '8px 12px', fontWeight: 600, textAlign: 'left' }}>Source</th>
                  </tr>
                </thead>
                <tbody>
                  {s.recentTransactions.map((t) => (
                    <TransactionRow
                      key={t.id}
                      tx={{{
                        id: t.id,
                        familyId,
                        amountCents: t.amountCents,
                        bookingDate: new Date(t.date),
                        label: t.label,
                        source: t.source as any,
                        categoryId: undefined,
                        personId: undefined,
                        isDeleted: t.isDeleted,
                      }>}}
                      categoryName={t.categoryName}
                      personName={t.personName}
                    />
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* États vides pour sections sans données */}
        {!s.byCategory.length && visibleCards.includes('spending') && (
          <div style={{ marginBottom: 20 }}>}
            <EmptyState
              title="Aucune dépense enregistrée"
              description="Ajoutez votre première transaction pour voir vos dépenses par catégorie."
              actionLabel="Ajouter une transaction"
              actionHref="/transactions"
              icon="📭"
            />
          </div>
        )}
        {!s.budgetsWithUsage.length && visibleCards.includes('spending') && (
          <div style={{ marginBottom: 20 }}>}
            <EmptyState
              title="Aucun budget défini"
              description="Créez un budget pour suivre vos dépenses par rapport à vos objectifs."
              actionLabel="Créer un budget"
              actionHref="/budgets"
              icon="💰"
            />
          </div>
        )}
        {!s.goalsStats.length && visibleCards.includes('goals') && (
          <div style={{ marginBottom: 20 }}>}
            <EmptyState
              title="Aucun objectif d'épargne"
              description="Définissez une cible d'épargne et suivez votre progression."
              actionLabel="Créer un objectif"
              actionHref="/objectifs"
              icon="🎯"
            />
          </div>
        )}
        {!s.recentTransactions.length && (visibleCards.includes('recent-transactions') || visibleCards.includes('spending')) && (
          <div>
            <EmptyState
              title="Aucune transaction récente"
              description="Vos transactions apparaîtront ici une fois enregistrées."
              actionLabel="Ajouter une transaction"
              actionHref="/transactions"
              icon="📭"
            />
          </div>
        )}
      </div>
    </main>
  );
}

function Header() {
  return (
    <div
      style={{{
        width: 240,
        background: COLOR_DARK,
        color: 'white',
        minHeight: '100vh',
        padding: 16,
        position: 'fixed',
        left: 0,
        top: 0,
        boxSizing: 'border-box',
      }}}
    >
      <h2
        style={{ color: COLOR_PRIMARY, marginBottom: 24, fontSize: 18, margin: 0 }}
      >
        TENΛ Budget
      </h2>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {[
          { href: '/dashboard', label: 'Tableau de bord', icon: '📊' },
          { href: '/famille', label: 'Famille', icon: '👨‍👩‍👧‍👦' },
          { href: '/budgets', label: 'Budgets', icon: '💰' },
          { href: '/transactions', label: 'Transactions', icon: '💳' },
          { href: '/historique', label: 'Historique', icon: '📈' },
          { href: '/simulations', label: 'Simulations', icon: '🔮' },
          { href: '/assistant', label: 'Assistant TENΛ', icon: '🤖' },
          { href: '/exports', label: 'Exports', icon: '📤' },
          { href: '/sauvegardes', label: 'Sauvegardes', icon: '💾' },
        ].map((l) => (
          <Link
            key={l.href}
            href={l.href}
            style={{{
              padding: '8px 12px',
              borderRadius: 8,
              background: '#7C3AED',
              color: 'white',
              textDecoration: 'none',
              display: 'flex',
              gap: 8,
              fontSize: 13,
              fontWeight: 500,
            }}}
          >
            <span>{l.icon}</span> {l.label}
          </Link>
        ))}
      </div>
      <div style={{ marginTop: 32, padding: 12, background: '#1A1A1B', borderRadius: 8 }}>
        <p style={{ fontSize: 12, color: '#888', margin: 0 }}}{APP_NAME}</p>
        <p style={{ fontSize: 11, color: '#666', margin: 4, marginTop: 8 }}>Local-first • Offline-ready</p>
        <p style={{ fontSize: 11, color: COLOR_SUCCESS, margin: 4 }}>● En ligne</p>
      </div>
    </div>
  );
}
