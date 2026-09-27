import { PrismaClient } from "@prisma/client";

declare global {
  // eslint-disable-next-line no-var
  var tenaPrisma: PrismaClient | undefined;
}

export const prisma =
  globalThis.tenaPrisma ??
  new PrismaClient();

if (process.env.NODE_ENV !== "production") {
  globalThis.tenaPrisma = prisma;
}
