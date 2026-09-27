
import { describe, it, expect } from "vitest";
import { createRecurringRule, generateOccurrences, createGenerationLog, softDeleteRecurringRule } from "./recurring";
import { createSavingGoal, addContribution, calculateProgress, softDeleteGoal } from "./savings";
import { getBudgetsByPerson, getFamilyGlobalBudgets, calculateRemainingByPerson, calculateFamilyRemaining } from "./personBudget";
import { createBudget } from "./budget";
import { createTransaction } from "./transaction";

describe("Dépenses récurrentes - règle distincte", () => {
  it("crée règle hebdo", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Abonnement", amountCents: 1000, periodicity: "weekly", dayOfWeek: 1, startDate: new Date("2026-01-01"), createdByUserId: "u1" }, "admin");
    expect(rule.periodicity).toBe("weekly");
    expect(rule.dayOfWeek).toBe(1);
    expect(rule.isDeleted).toBe(false);
  });
  it("crée règle mensuelle", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Loyer", amountCents: 80000, periodicity: "monthly", dayOfMonth: 5, startDate: new Date("2026-01-01"), createdByUserId: "u1" }, "owner");
    expect(rule.dayOfMonth).toBe(5);
  });
  it("refuse montant nul", () => {
    expect(() => createRecurringRule({ familyId: "fam1", label: "Test", amountCents: 0, periodicity: "weekly", dayOfWeek: 1, startDate: new Date(), createdByUserId: "u1" }, "admin")).toThrow("ZERO");
  });
  it("refuse montant négatif", () => {
    expect(() => createRecurringRule({ familyId: "fam1", label: "Test", amountCents: -100, periodicity: "weekly", dayOfWeek: 1, startDate: new Date(), createdByUserId: "u1" }, "admin")).toThrow("NEGATIVE");
  });
  it("refuse float", () => {
    expect(() => createRecurringRule({ familyId: "fam1", label: "Test", amountCents: 10.5 as any, periodicity: "weekly", dayOfWeek: 1, startDate: new Date(), createdByUserId: "u1" }, "admin")).toThrow("INT_ONLY");
  });
  it("génère occurrences hebdo", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Sport", amountCents: 2000, periodicity: "weekly", dayOfWeek: 1, startDate: new Date("2026-01-01"), createdByUserId: "u1" }, "admin");
    const occ = generateOccurrences(rule, new Date("2026-01-01"), new Date("2026-01-31"));
    expect(occ.length).toBeGreaterThanOrEqual(4);
    expect(occ[0].amountCents).toBe(2000);
  });
  it("génère occurrences mensuelles", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Loyer", amountCents: 80000, periodicity: "monthly", dayOfMonth: 5, startDate: new Date("2026-01-01"), createdByUserId: "u1" }, "owner");
    const occ = generateOccurrences(rule, new Date("2026-01-01"), new Date("2026-03-31"));
    expect(occ.length).toBe(3);
  });
  it("ne crée pas transaction réelle sans validation - log pending", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Test", amountCents: 1000, periodicity: "weekly", dayOfWeek: 1, startDate: new Date("2026-01-01"), createdByUserId: "u1" }, "admin");
    const occ = generateOccurrences(rule, new Date("2026-01-01"), new Date("2026-01-08"))[0];
    const log = createGenerationLog(rule, occ, "admin");
    expect(log.status).toBe("pending_validation");
    expect(log.generatedTransactionId).toBeUndefined();
  });
  it("historique générations", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Test", amountCents: 1000, periodicity: "weekly", dayOfWeek: 1, startDate: new Date("2026-01-01"), createdByUserId: "u1" }, "admin");
    const occs = generateOccurrences(rule, new Date("2026-01-01"), new Date("2026-01-31"));
    expect(occs.length).toBeGreaterThan(0);
  });
  it("soft delete règle", () => {
    const rule = createRecurringRule({ familyId: "fam1", label: "Test", amountCents: 1000, periodicity: "weekly", dayOfWeek: 1, startDate: new Date(), createdByUserId: "u1" }, "admin");
    const deleted = softDeleteRecurringRule(rule, "admin");
    expect(deleted.isDeleted).toBe(true);
    expect(generateOccurrences(deleted, new Date(), new Date(Date.now()+86400000*30)).length).toBe(0);
  });
});

describe("Objectifs épargne - targetCents Int, progression sans float", () => {
  it("crée objectif", () => {
    const goal = createSavingGoal({ familyId: "fam1", name: "Vacances", targetCents: 200000 }, "owner");
    expect(goal.targetCents).toBe(200000);
    expect(goal.currentCents).toBe(0);
  });
  it("refuse target float", () => {
    expect(() => createSavingGoal({ familyId: "fam1", name: "Test", targetCents: 100.5 as any }, "owner")).toThrow("INT_ONLY");
  });
  it("refuse target nul/négatif", () => {
    expect(() => createSavingGoal({ familyId: "fam1", name: "Test", targetCents: 0 }, "owner")).toThrow("POSITIVE");
    expect(() => createSavingGoal({ familyId: "fam1", name: "Test", targetCents: -100 }, "owner")).toThrow("POSITIVE");
  });
  it("ajoute contribution Int", () => {
    let goal = createSavingGoal({ familyId: "fam1", name: "Vacances", targetCents: 200000 }, "owner");
    const res = addContribution(goal, { amountCents: 50000, createdByUserId: "u1" }, "admin", []);
    expect(res.goal.currentCents).toBe(50000);
    expect(res.contribution.amountCents).toBe(50000);
  });
  it("progression sans float", () => {
    let goal = createSavingGoal({ familyId: "fam1", name: "Vacances", targetCents: 200000 }, "owner");
    const res = addContribution(goal, { amountCents: 50000, createdByUserId: "u1" }, "admin", []);
    const prog = calculateProgress(res.goal);
    expect(prog.currentCents).toBe(50000);
    expect(prog.targetCents).toBe(200000);
    expect(prog.remainingCents).toBe(150000);
    expect(prog.percentInt).toBe(25);
    expect(Number.isInteger(prog.percentInt)).toBe(true);
  });
  it("objectif dépassé", () => {
    let goal = createSavingGoal({ familyId: "fam1", name: "Vacances", targetCents: 100000 }, "owner");
    const r1 = addContribution(goal, { amountCents: 80000, createdByUserId: "u1" }, "admin", []);
    const r2 = addContribution(r1.goal, { amountCents: 50000, createdByUserId: "u1" }, "admin", []);
    const prog = calculateProgress(r2.goal);
    expect(prog.isExceeded).toBe(true);
    expect(prog.remainingCents).toBe(-30000);
  });
  it("refuse contribution fait passer en négatif", () => {
    let goal = createSavingGoal({ familyId: "fam1", name: "Vacances", targetCents: 100000 }, "owner");
    expect(() => addContribution(goal, { amountCents: -1000, createdByUserId: "u1" }, "admin", [])).toThrow("NEGATIVE_CURRENT");
  });
  it("indépendant simulations", () => {
    const goal = createSavingGoal({ familyId: "fam1", name: "Test", targetCents: 100000 }, "owner");
    expect(goal.id.startsWith("goal_")).toBe(true);
    // Pas de lien avec sim_
  });
});

describe("Budgets par personne", () => {
  it("ne mélange pas familial global et individuel", () => {
    const globalBudget = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 400000 }, "owner", []);
    const personBudget = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 100000, personId: "p1" }, "owner", []);
    const budgets = [globalBudget, personBudget];
    expect(getFamilyGlobalBudgets(budgets).length).toBe(1);
    expect(getBudgetsByPerson(budgets, "p1").length).toBe(1);
  });
  it("calcul par personne avec plusieurs personnes", () => {
    const b1 = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 100000, personId: "p1", categoryId: "cat1" }, "owner", []);
    const b2 = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 200000, personId: "p2", categoryId: "cat1" }, "owner", []);
    const tx1 = createTransaction({ familyId: "fam1", amountCents: 20000, bookingDate: new Date(), label: "P1 course", source: "manual", personId: "p1", categoryId: "cat1", createdByUserId: "u1" }, "owner");
    const tx2 = createTransaction({ familyId: "fam1", amountCents: 50000, bookingDate: new Date(), label: "P2 course", source: "manual", personId: "p2", categoryId: "cat1", createdByUserId: "u1" }, "owner");
    const remP1 = calculateRemainingByPerson([b1,b2], [tx1,tx2] as any, "p1");
    expect(remP1[0].remainingCents).toBe(80000);
  });
  it("transactions supprimées ignorées dans calcul personne", () => {
    const b = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 100000, personId: "p1" }, "owner", []);
    const tx = createTransaction({ familyId: "fam1", amountCents: 50000, bookingDate: new Date(), label: "Test", source: "manual", personId: "p1", createdByUserId: "u1" }, "owner");
    const deleted = { ...tx, isDeleted: true } as any;
    const rem = calculateRemainingByPerson([b], [deleted] as any, "p1");
    expect(rem[0].remainingCents).toBe(100000);
  });
});

describe("Cas limites", () => {
  it("montant nul interdit", () => {
    expect(() => createRecurringRule({ familyId: "fam1", label: "Test", amountCents: 0, periodicity: "weekly", dayOfWeek: 1, startDate: new Date(), createdByUserId: "u1" }, "admin")).toThrow();
  });
  it("soft delete obligatoire", () => {
    const goal = createSavingGoal({ familyId: "fam1", name: "Test", targetCents: 100000 }, "owner");
    const deleted = softDeleteGoal(goal, "admin");
    expect(deleted.isDeleted).toBe(true);
  });
});
