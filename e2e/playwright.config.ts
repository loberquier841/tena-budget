
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  timeout: 30000,
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'pnpm dev',
    port: 3000,
    reuseExistingServer: true,
  },
});
