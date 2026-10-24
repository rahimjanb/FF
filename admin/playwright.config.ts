import { defineConfig } from '@playwright/test'

// End-to-end tests of the admin panel against a REAL running backend.
// Uses the locally installed Google Chrome (no browser download). See docs/TESTING.md.
export default defineConfig({
  testDir: './e2e',
  timeout: 60_000,
  retries: 0,
  workers: 1, // specs share one database and compare report totals
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:5173',
    channel: 'chrome',
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: true,
    timeout: 60_000,
  },
})
