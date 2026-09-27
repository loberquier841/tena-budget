
import { Role, assertCan } from "../permissions/permissions";

export interface Category {
  id: string;
  familyId: string;
  name: string;
  parentId: string | null;
  isArchived: boolean;
  createdAt: Date;
}

export function createCategory(input: { familyId: string; name: string; parentId?: string | null }, role: Role, existing: Category[]): Category {
  assertCan(role, "budget:write");
  if (!input.name.trim()) throw new Error("CATEGORY_NAME_REQUIRED");
  const dup = existing.find(c => c.familyId === input.familyId && c.name.toLowerCase() === input.name.toLowerCase() && c.parentId === (input.parentId || null) && !c.isArchived);
  if (dup) throw new Error("CATEGORY_DUPLICATE");
  if (input.parentId) {
    const parent = existing.find(c => c.id === input.parentId);
    if (!parent) throw new Error("PARENT_NOT_FOUND");
    if (parent.parentId) throw new Error("CATEGORY_DEPTH_LIMIT: 2 niveaux max (catégorie + sous-catégorie)");
  }
  return {
    id: `cat_${Date.now()}_${Math.random().toString(36).slice(2,6)}`,
    familyId: input.familyId,
    name: input.name.trim(),
    parentId: input.parentId || null,
    isArchived: false,
    createdAt: new Date(),
  };
}

export function updateCategory(cat: Category, patch: { name?: string }, role: Role): Category {
  assertCan(role, "budget:write");
  if (patch.name !== undefined) {
    if (!patch.name.trim()) throw new Error("CATEGORY_NAME_REQUIRED");
    return { ...cat, name: patch.name.trim() };
  }
  return cat;
}

export function archiveCategory(cat: Category, role: Role): Category {
  assertCan(role, "budget:write");
  return { ...cat, isArchived: true };
}

export function getCategoryTree(categories: Category[]): { parents: Category[]; getChildren: (parentId: string) => Category[] } {
  const parents = categories.filter(c => !c.parentId && !c.isArchived);
  const getChildren = (parentId: string) => categories.filter(c => c.parentId === parentId && !c.isArchived);
  return { parents, getChildren };
}
