
import { Role, assertCan, requiresOwnerConfirmation } from "../permissions/permissions";

export interface SavingGoal {
  id: string;
  familyId: string;
  personId?: string;
  name: string;
  targetCents: number; // entier
  currentCents: number; // montant actuel Int sans float
  isArchived: boolean;
  createdAt: Date;
  updatedAt: Date;
  isDeleted: boolean;
  deletedAt?: Date;
}

export interface SavingContribution {
  id: string;
  goalId: string;
  amountCents: number; // Int positif ajout, négatif retrait
  bookingDate: Date;
  note?: string;
  createdByUserId: string;
}

export function validateSavingTarget(targetCents: number): void {
  if (!Number.isInteger(targetCents)) throw new Error("GOAL_TARGET_INT_ONLY");
  if (targetCents <= 0) throw new Error("GOAL_TARGET_POSITIVE_REQUIRED");
}

export function createSavingGoal(input: { familyId: string; personId?: string; name: string; targetCents: number }, role: Role): SavingGoal {
  assertCan(role, "budget:write");
  validateSavingTarget(input.targetCents);
  if (!input.name.trim()) throw new Error("GOAL_NAME_REQUIRED");
  if (requiresOwnerConfirmation(input.targetCents) && role !== "owner") throw new Error("GOAL_REQUIRES_OWNER: >500€");
  return {
    id: `goal_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: input.familyId,
    personId: input.personId,
    name: input.name.trim(),
    targetCents: input.targetCents,
    currentCents: 0,
    isArchived: false,
    createdAt: new Date(),
    updatedAt: new Date(),
    isDeleted: false,
  };
}

export function addContribution(goal: SavingGoal, contribution: { amountCents: number; note?: string; createdByUserId: string }, role: Role, existingContributions: SavingContribution[]): { goal: SavingGoal; contribution: SavingContribution } {
  assertCan(role, "budget:write");
  if (goal.isDeleted) throw new Error("GOAL_DELETED");
  if (!Number.isInteger(contribution.amountCents)) throw new Error("CONTRIBUTION_INT_ONLY");
  if (contribution.amountCents === 0) throw new Error("CONTRIBUTION_ZERO_FORBIDDEN");
  if (goal.isArchived) throw new Error("GOAL_ARCHIVED");

  const newCurrent = goal.currentCents + contribution.amountCents;
  // Progression sans float - Int only
  if (newCurrent < 0) throw new Error("GOAL_NEGATIVE_CURRENT_FORBIDDEN");

  const contrib: SavingContribution = {
    id: `cont_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    goalId: goal.id,
    amountCents: contribution.amountCents,
    bookingDate: new Date(),
    note: contribution.note,
    createdByUserId: contribution.createdByUserId,
  };

  const updatedGoal: SavingGoal = {
    ...goal,
    currentCents: newCurrent,
    updatedAt: new Date(),
  };

  return { goal: updatedGoal, contribution: contrib };
}

export function calculateProgress(goal: SavingGoal): { currentCents: number; targetCents: number; remainingCents: number; percentInt: number; isExceeded: boolean } {
  // Sans float - percentInt = floor(current*100/target)
  const remainingCents = goal.targetCents - goal.currentCents;
  const percentInt = Math.floor((goal.currentCents * 100) / goal.targetCents);
  const isExceeded = goal.currentCents > goal.targetCents;
  return {
    currentCents: goal.currentCents,
    targetCents: goal.targetCents,
    remainingCents,
    percentInt,
    isExceeded,
  };
}

export function softDeleteGoal(goal: SavingGoal, role: Role): SavingGoal {
  assertCan(role, "budget:write");
  if (goal.isDeleted) throw new Error("GOAL_ALREADY_DELETED");
  return { ...goal, isDeleted: true, deletedAt: new Date(), updatedAt: new Date() };
}

export function archiveGoal(goal: SavingGoal, role: Role): SavingGoal {
  assertCan(role, "budget:write");
  return { ...goal, isArchived: true, updatedAt: new Date() };
}
