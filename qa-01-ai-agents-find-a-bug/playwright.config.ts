import { defineConfig } from '@playwright/test';

const PORT = Number(process.env.PORT ?? 3100);
const FIXED = process.env.APP_FIXED === '1';

export default defineConfig({
  testDir: './tests',
  reporter: [['list']],
  use: {
    baseURL: `http://localhost:${PORT}`,
    channel: 'chrome', // the laptop's installed Google Chrome: no browser download needed
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'demo', testDir: './tests' }, // what the agents write during the session
    { name: 'reference', testDir: './reference/tests' }, // fallback if the live AI run drifts
  ],
  webServer: {
    command: `node app/server.mjs${FIXED ? ' --fixed' : ''}`,
    url: `http://localhost:${PORT}/health`,
    reuseExistingServer: true,
    env: { PORT: String(PORT) },
  },
});
