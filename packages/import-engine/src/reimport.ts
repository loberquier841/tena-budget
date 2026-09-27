
import { hashDedup } from "./parser";

// Réimport capable de reconnaître déjà importées
export function isAlreadyImported(incomingHash: string, existingHashes: Set<string>): boolean {
  return existingHashes.has(incomingHash);
}

export function filterNewTransactions(incoming: { hashDedup: string }[], existingHashes: Set<string>): { newOnes: typeof incoming; alreadyImported: typeof incoming } {
  const newOnes: typeof incoming = [];
  const alreadyImported: typeof incoming = [];
  for (const tx of incoming) {
    if (isAlreadyImported(tx.hashDedup, existingHashes)) {
      alreadyImported.push(tx);
    } else {
      newOnes.push(tx);
    }
  }
  return { newOnes, alreadyImported };
}
