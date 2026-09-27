
import { Role, assertCan, requiresOwnerConfirmation } from "../permissions/permissions";

export type Periodicity = 'weekly' | 'monthly';

export interface RecurringRule {
  id: string;
  familyId: string;
  personId?: string; // budget par personne
  categoryId?: string;
  label: string;
  amountCents: number; // Int centimes
  periodicity: Periodicity;
  dayOfWeek?: number; // 0-6
  dayOfMonth?: number; // 1-31
  startDate: Date;
  endDate?: Date;
  isActive: boolean;
  createdByUserId: string;
  createdAt: Date;
  updatedAt: Date;
  isDeleted: boolean;
  deletedAt?: Date;
}

export interface GenerationLog {
  id: string;
  ruleId: string;
  generatedAt: Date;
  generatedTransactionId?: string;
  periodStart: Date;
  periodEnd: Date;
  amountCents: number;
  status: 'pending_validation' | 'generated' | 'skipped';
}

export function validateRecurringAmount(amountCents: number): void {
  if (!Number.isInteger(amountCents)) throw new Error("RECURRING_AMOUNT_INT_ONLY");
  if (amountCents === 0) throw new Error("RECURRING_ZERO_FORBIDDEN");
  if (amountCents < 0) throw new Error("RECURRING_NEGATIVE_FORBIDDEN: montant doit être positif, le signe sera géré par catégorie");
}

export function createRecurringRule(input: { familyId: string; personId?: string; categoryId?: string; label: string; amountCents: number; periodicity: Periodicity; dayOfWeek?: number; dayOfMonth?: number; startDate: Date; endDate?: Date; createdByUserId: string }, role: Role): RecurringRule {
  assertCan(role, "budget:write");
  validateRecurringAmount(input.amountCents);
  if (!input.label.trim()) throw new Error("RECURRING_LABEL_REQUIRED");
  if (input.periodicity === 'weekly' && (input.dayOfWeek === undefined || input.dayOfWeek < 0 || input.dayOfWeek > 6)) throw new Error("RECURRING_DAYOFWEEK_REQUIRED");
  if (input.periodicity === 'monthly' && (input.dayOfMonth === undefined || input.dayOfMonth < 1 || input.dayOfMonth > 31)) throw new Error("RECURRING_DAYOFMONTH_REQUIRED");
  if (input.endDate && input.endDate < input.startDate) throw new Error("RECURRING_END_BEFORE_START");
  if (requiresOwnerConfirmation(input.amountCents) && role !== "owner") throw new Error("RECURRING_REQUIRES_OWNER: >500€");

  return {
    id: `rec_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: input.familyId,
    personId: input.personId,
    categoryId: input.categoryId,
    label: input.label.trim(),
    amountCents: input.amountCents,
    periodicity: input.periodicity,
    dayOfWeek: input.dayOfWeek,
    dayOfMonth: input.dayOfMonth,
    startDate: input.startDate,
    endDate: input.endDate,
    isActive: true,
    createdByUserId: input.createdByUserId,
    createdAt: new Date(),
    updatedAt: new Date(),
    isDeleted: false,
  };
}

export function softDeleteRecurringRule(rule: RecurringRule, role: Role): RecurringRule {
  assertCan(role, "budget:write");
  if (rule.isDeleted) throw new Error("RECURRING_ALREADY_DELETED");
  return { ...rule, isDeleted: true, deletedAt: new Date(), isActive: false, updatedAt: new Date() };
}

// Génère les occurrences prévues entre deux dates - ne crée PAS de Transaction réelle automatiquement
export function generateOccurrences(rule: RecurringRule, from: Date, to: Date): { periodStart: Date; periodEnd: Date; amountCents: number }[] {
  if (rule.isDeleted || !rule.isActive) return [];
  const occurrences: { periodStart: Date; periodEnd: Date; amountCents: number }[] = [];
  let cursor = new Date(rule.startDate);
  if (cursor < from) cursor = new Date(from);
  const end = rule.endDate && rule.endDate < to ? rule.endDate : to;

  while (cursor <= end) {
    let next: Date;
    if (rule.periodicity === 'weekly') {
      // Trouve prochain dayOfWeek
      const diff = (rule.dayOfWeek! - cursor.getDay() + 7) % 7;
      const occurrence = new Date(cursor);
      occurrence.setDate(cursor.getDate() + diff);
      if (occurrence < from) {
        cursor.setDate(cursor.getDate() + 7);
        continue;
      }
      if (occurrence > end) break;
      next = new Date(occurrence);
      next.setDate(next.getDate() + 7);
      occurrences.push({ periodStart: occurrence, periodEnd: next, amountCents: rule.amountCents });
      cursor = next;
    } else {
      // monthly
      const occurrence = new Date(cursor.getFullYear(), cursor.getMonth(), rule.dayOfMonth!);
      if (occurrence < cursor) {
        cursor = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
        continue;
      }
      if (occurrence < from) {
        cursor = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
        continue;
      }
      if (occurrence > end) break;
      next = new Date(occurrence.getFullYear(), occurrence.getMonth() + 1, rule.dayOfMonth!);
      occurrences.push({ periodStart: occurrence, periodEnd: next, amountCents: rule.amountCents });
      cursor = next;
    }
  }
  return occurrences;
}

// Crée un log de génération - respecte permissions et validation
export function createGenerationLog(rule: RecurringRule, occurrence: { periodStart: Date; periodEnd: Date; amountCents: number }, role: Role): GenerationLog {
  assertCan(role, "transaction:write");
  // Ne jamais créer automatiquement une Transaction réelle sans validation - on crée un log pending_validation
  return {
    id: `gen_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    ruleId: rule.id,
    generatedAt: new Date(),
    periodStart: occurrence.periodStart,
    periodEnd: occurrence.periodEnd,
    amountCents: occurrence.amountCents,
    status: 'pending_validation',
  };
}

export function confirmGeneration(log: GenerationLog, transactionId: string): GenerationLog {
  // Après validation utilisateur, on lie à la Transaction réelle créée
  return { ...log, generatedTransactionId: transactionId, status: 'generated' as const };
}
