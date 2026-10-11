import { checkRateLimit, attemptMap } from './rateLimit.js';

// Clear map
attemptMap.clear();
const ip = '1.2.3.4';

// Simulate 5 attempts
for (let i = 0; i < 5; i++) {
  const res = checkRateLimit(ip);
  console.log(`Attempt ${i+1}: allowed=${res.allowed}`);
}
// 6th attempt should be blocked
const res6 = checkRateLimit(ip);
console.log(`Attempt 6: allowed=${res6.allowed}`);
// Clear map to simulate window passed
attemptMap.clear();
// Next attempt should be allowed
const res7 = checkRateLimit(ip);
console.log(`After clear: allowed=${res7.allowed}`);
