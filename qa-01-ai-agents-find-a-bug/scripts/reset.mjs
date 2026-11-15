// Reset qa-01 before a session or a rehearsal: removes what the agents wrote last time.
// Keeps tests/seed.spec.ts, specs/README.md, the agent definitions and reference/.
// Run: npm run reset
import { readdirSync, rmSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const keep = { tests: ['seed.spec.ts'], specs: ['README.md'] };
let removed = 0;
for (const [dir, kept] of Object.entries(keep)) {
  if (!existsSync(dir)) continue;
  for (const name of readdirSync(dir)) {
    if (kept.includes(name)) continue;
    rmSync(join(dir, name), { recursive: true, force: true });
    removed++;
  }
}
for (const dir of ['receipts', 'test-results', 'playwright-report']) {
  if (existsSync(dir)) { rmSync(dir, { recursive: true, force: true }); removed++; }
}
console.log(`qa-01 ready: removed ${removed} item(s). Start the app with: npm start`);
