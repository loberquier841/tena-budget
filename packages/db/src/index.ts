
export * from "@prisma/client";
// Helper pour vérifier secrets côté serveur only
export function assertServerOnly() {
  if (typeof window !== "undefined") throw new Error("DB_ACCESS_FORBIDDEN_CLIENT");
}

export { prisma } from "./client";
