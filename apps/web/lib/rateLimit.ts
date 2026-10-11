// Rate limiting utility for authentication attempts
export const LIMIT = 5; // max attempts
export const WINDOW_MS = 5 * 60 * 1000; // 5 minutes

interface Attempt {
  count: number;
  firstAttempt: number;
}

export const attemptMap = new Map<string, Attempt>();

export function cleanupAttempts() {
  const now = Date.now();
  for (const [ip, data] of attemptMap.entries()) {
    if (now - data.firstAttempt > WINDOW_MS) {
      attemptMap.delete(ip);
    }
  }
}

/**
 * Check if the given IP is allowed to make another attempt.
 * Returns an object with allowed boolean.
 * If allowed, increments the internal counter.
 */
export function checkRateLimit(ip: string): { allowed: boolean } {
  cleanupAttempts();

  const now = Date.now();
  const existing = attemptMap.get(ip);

  let count = existing?.count ?? 0;
  let firstAttempt = existing?.firstAttempt ?? now;

  // Reset if window expired or exactly at window boundary
  if (now - firstAttempt >= WINDOW_MS) {
    count = 0;
    firstAttempt = now;
  }

  if (count >= LIMIT) {
    return { allowed: false };
  }

  count += 1;
  attemptMap.set(ip, { count, firstAttempt });

  return { allowed: true };
}