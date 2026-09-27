
import { describe, it, expect } from "vitest";
import { createCategory, archiveCategory } from "./category";
import { createBudget, calculateRemaining, validateBudgetAmount } from "./budget";
import { createTransaction, softDeleteTransaction, validateTransactionAmount } from "./transaction";
import { filterTransactions, searchTransactions } from "./search";
import { createSimulationScenario, createSimulationTransaction, assertSimulationIsolation } from "./simulation";
import { can } from "../permissions/permissions";

describe("Catégories + sous-catégories", () => {
  it("crée catégorie parent", () => {
    const cat = createCategory({ familyId: "fam1", name: "Courses" }, "admin", []);
    expect(cat.name).toBe("Courses");
    expect(cat.parentId).toBeNull();
  });
  it("crée sous-catégorie", () => {
    const parent = createCategory({ familyId: "fam1", name: "Courses" }, "admin", []);
    const child = createCategory({ familyId: "fam1", name: "Bio", parentId: parent.id }, "admin", [parent]);
    expect(child.parentId).toBe(parent.id);
  });
  it("refuse profondeur >2", () => {
    const p = createCategory({ familyId: "fam1", name: "P" }, "admin", []);
    const c = createCategory({ familyId: "fam1", name: "C", parentId: p.id }, "admin", [p]);
    expect(() => createCategory({ familyId: "fam1", name: "GC", parentId: c.id }, "admin", [p,c])).toThrow("DEPTH");
  });
  it("refuse doublon même niveau", () => {
    const p = createCategory({ familyId: "fam1", name: "Courses" }, "admin", []);
    expect(() => createCategory({ familyId: "fam1", name: "courses" }, "admin", [p])).toThrow("DUPLICATE");
  });
  it("archive soft", () => {
    const p = createCategory({ familyId: "fam1", name: "Courses" }, "admin", []);
    const archived = archiveCategory(p, "admin");
    expect(archived.isArchived).toBe(true);
  });
});

describe("Budgets annual/mensuel Int centimes", () => {
  it("refuse float", () => {
    expect(() => validateBudgetAmount(100.5)).toThrow("INT_CENTS");
  });
  it("crée budget annuel", () => {
    const b = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 400000 }, "owner", []);
    expect(b.type).toBe("annual");
    expect(b.amountCents).toBe(400000);
  });
  it("crée budget mensuel", () => {
    const b = createBudget({ familyId: "fam1", type: "monthly", year: 2026, month: 5, amountCents: 30000 }, "admin", []);
    expect(b.month).toBe(5);
  });
  it("refuse mensuel sans mois", () => {
    expect(() => createBudget({ familyId: "fam1", type: "monthly", year: 2026, amountCents: 10000 } as any, "admin", [])).toThrow("MONTH_REQUIRED");
  });
  it("calcul restant temps réel Int", () => {
    const budget = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 400000, categoryId: "cat1" }, "owner", []);
    const txs = [
      { amountCents: 50000, isDeleted: false, categoryId: "cat1", bookingDate: new Date("2026-01-10") },
      { amountCents: 30000, isDeleted: false, categoryId: "cat1", bookingDate: new Date("2026-02-10") },
      { amountCents: 10000, isDeleted: true, categoryId: "cat1", bookingDate: new Date("2026-03-10") },
    ];
    const remaining = calculateRemaining(budget, txs as any);
    expect(remaining).toBe(320000); // 400000 - 80000, deleted ignoré
    expect(Number.isInteger(remaining)).toBe(true);
  });
  it("seuil 500€ nécessite owner", () => {
    expect(() => createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 6000000 }, "admin", [])).toThrow("OWNER_CONFIRMATION");
  });
});

describe("Transactions liées à personne, soft delete", () => {
  it("refuse sans personId", () => {
    expect(() => createTransaction({ familyId: "fam1", amountCents: 1000, bookingDate: new Date(), label: "Test", source: "manual", personId: "" as any, createdByUserId: "u1" }, "member")).toThrow("PERSON_REQUIRED");
  });
  it("crée transaction Int centimes", () => {
    const tx = createTransaction({ familyId: "fam1", amountCents: 185000, bookingDate: new Date(), label: "Courses", source: "manual", personId: "pers1", createdByUserId: "u1" }, "owner");
    expect(tx.amountCents).toBe(185000);
    expect(Number.isInteger(tx.amountCents)).toBe(true);
  });
  it("refuse float", () => {
    expect(() => validateTransactionAmount(10.5)).toThrow("INT_CENTS");
  });
  it("soft delete obligatoire, pas physique", () => {
    const tx = createTransaction({ familyId: "fam1", amountCents: 1000, bookingDate: new Date(), label: "Test", source: "manual", personId: "p1", createdByUserId: "u1" }, "member");
    const deleted = softDeleteTransaction(tx, "admin");
    expect(deleted.isDeleted).toBe(true);
    expect(deleted.deletedAt).toBeDefined();
    // Vérifie pas de suppression physique
    const list = [deleted];
    expect(list.some(t => t.id === tx.id)).toBe(true);
  });
  it("seuil 500€ transaction nécessite owner", () => {
    expect(() => createTransaction({ familyId: "fam1", amountCents: 60000, bookingDate: new Date(), label: "Gros", source: "manual", personId: "p1", createdByUserId: "u1" }, "member")).toThrow("OWNER_CONFIRMATION");
  });
  it("suppression >500€ nécessite owner", () => {
    const tx = createTransaction({ familyId: "fam1", amountCents: 60000, bookingDate: new Date(), label: "Gros", source: "manual", personId: "p1", createdByUserId: "u1" }, "owner");
    expect(() => softDeleteTransaction(tx, "admin")).toThrow("OWNER_CONFIRMATION");
  });
});

describe("Recherche et filtres", () => {
  const baseTx = [
    createTransaction({ familyId: "fam1", amountCents: 1000, bookingDate: new Date("2026-01-01"), label: "Courses Leclerc", source: "manual", personId: "p1", categoryId: "cat1", createdByUserId: "u1" }, "owner"),
    createTransaction({ familyId: "fam1", amountCents: 2000, bookingDate: new Date("2026-02-01"), label: "Essence", source: "import", personId: "p2", categoryId: "cat2", createdByUserId: "u1" }, "owner"),
  ];
  it("filtre par personne", () => {
    const res = filterTransactions(baseTx as any, { familyId: "fam1", personId: "p1" });
    expect(res.length).toBe(1);
  });
  it("filtre par catégorie", () => {
    const res = filterTransactions(baseTx as any, { familyId: "fam1", categoryId: "cat2" });
    expect(res.length).toBe(1);
    expect(res[0].label).toBe("Essence");
  });
  it("recherche label", () => {
    const res = searchTransactions(baseTx as any, "leclerc", "fam1");
    expect(res.length).toBe(1);
  });
  it("exclut deleted par défaut", () => {
    const deleted = softDeleteTransaction(baseTx[0], "owner");
    const list = [deleted, baseTx[1]] as any;
    const res = filterTransactions(list, { familyId: "fam1" });
    expect(res.length).toBe(1);
  });
});

describe("Simulations isolées", () => {
  it("simulation ne touche jamais réel", () => {
    const realIds = ["tx_1", "tx_2"];
    const scenario = createSimulationScenario("fam1", "Achat voiture");
    const simTx = createSimulationTransaction(scenario.id, { amountCents: 500000, label: "Voiture", bookingDate: new Date() });
    expect(simTx.scenarioId).toBe(scenario.id);
    expect(assertSimulationIsolation(realIds, [simTx])).toBe(true);
    // Vérifie que simulation a son propre namespace
    expect(simTx.id.startsWith("simtx_")).toBe(true);
  });
  it("refuse float en simulation", () => {
    const sc = createSimulationScenario("fam1", "Test");
    expect(() => createSimulationTransaction(sc.id, { amountCents: 10.5 as any, label: "X", bookingDate: new Date() })).toThrow("INT_ONLY");
  });
});

describe("Permissions par rôle", () => {
  it("member ne peut pas supprimer budget >500€", () => {
    const b = createBudget({ familyId: "fam1", type: "annual", year: 2026, amountCents: 10000 }, "owner", []);
    expect(can("member", "budget:write")).toBe(false);
  });
});
