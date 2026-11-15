// Records the "video receipt" for INV-142: the tenant leak, with chapter cards and highlighted actions.
// Uses Playwright's page.screencast API (Playwright 1.59+).
//
// Run: npm run receipt     (starts the app on port 3100 if it isn't running)
// Out: receipts/inv-142-tenant-leak.webm (open it in Chrome to play it)
import { chromium } from '@playwright/test';
import { spawn } from 'node:child_process';
import { mkdirSync } from 'node:fs';

const PORT = Number(process.env.PORT ?? 3100);
const BASE = `http://localhost:${PORT}`;
const OUT = 'receipts/inv-142-tenant-leak.webm';

async function appIsUp() {
  try { return (await fetch(`${BASE}/health`)).ok; } catch { return false; }
}

let server;
if (!(await appIsUp())) {
  server = spawn(process.execPath, ['app/server.mjs'], { env: { ...process.env, PORT: String(PORT) }, stdio: 'ignore' });
  for (let i = 0; i < 50 && !(await appIsUp()); i++) await new Promise((r) => setTimeout(r, 100));
}

mkdirSync('receipts', { recursive: true });
const browser = await chromium.launch({ channel: 'chrome' });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const started = Date.now();

try {
  await page.screencast.start({ path: OUT, size: { width: 1280, height: 720 } });
  await page.screencast.showActions({ position: 'top-right', duration: 900 });

  await page.goto(`${BASE}/login`);
  await page.screencast.showChapter('INV-142: Invoice list', {
    description: 'Signed in as Acme, the list must show only Acme invoices (ACM-...).',
    duration: 3000,
  });

  await page.getByRole('button', { name: 'Sign in as Acme' }).click();
  await page.getByRole('heading', { name: 'Invoices' }).waitFor();

  // Highlight the rows that belong to another organization.
  const leaked = await page.evaluate(() => {
    const rows = [...document.querySelectorAll('tbody tr')].filter((r) => r.cells[0].textContent.startsWith('GLX-'));
    rows.forEach((r) => { r.style.outline = '3px solid #e09a2d'; r.style.background = '#fdecc8'; });
    return rows.map((r) => r.cells[0].textContent);
  });

  await page.screencast.showChapter('Bug: Globex invoices on the Acme list', {
    description: `Page 1 shows ${leaked.join(' and ')}. The query has no tenant filter.`,
    duration: 4000,
  });
  await page.waitForTimeout(2500);

  await page.getByRole('link', { name: 'Next page' }).click();
  await page.evaluate(() => {
    [...document.querySelectorAll('tbody tr')]
      .filter((r) => r.cells[0].textContent.startsWith('GLX-'))
      .forEach((r) => { r.style.outline = '3px solid #e09a2d'; r.style.background = '#fdecc8'; });
  });
  await page.waitForTimeout(2500);

  await page.screencast.showChapter('Expected', {
    description: 'Every invoice number starts with ACM-. Fix the query, not the test.',
    duration: 3000,
  });
} finally {
  await page.screencast.stop();
  await browser.close();
  server?.kill();
}

console.log(`Saved ${OUT} in ${((Date.now() - started) / 1000).toFixed(1)} s`);
