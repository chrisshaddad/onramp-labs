// Checks qa-01 end to end, without the AI part. Run: npm run verify
// 1. The reference tests fail on the planted bug, and only the tenant test fails.
// 2. The same tests pass on the fixed app.
// 3. The receipt video records.
// 4. The agent definitions and MCP config are in place.
import { spawnSync } from 'node:child_process';
import { existsSync, statSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import os from 'node:os';

const results = [];
const check = (name, ok, detail) => { results.push({ name, ok, detail }); };
const run = (args, env) => {
  const t0 = Date.now();
  const r = spawnSync('npx', args, { env: { ...process.env, ...env }, encoding: 'utf8', shell: process.platform === 'win32' });
  return { ...r, seconds: ((Date.now() - t0) / 1000).toFixed(1) };
};
const summary = (r) => {
  const json = JSON.parse(r.stdout);
  const specs = json.suites.flatMap(function flat(s) { return [...(s.specs ?? []), ...(s.suites ?? []).flatMap(flat)]; });
  return specs.map((s) => ({ title: s.title, ok: s.ok }));
};

// 1. Planted bug
const buggy = run(['playwright', 'test', '--project=reference', '--reporter=json'], { PORT: '3101' });
try {
  const s = summary(buggy);
  const failed = s.filter((t) => !t.ok).map((t) => t.title);
  check('Buggy app: only the tenant test fails', failed.length === 1 && failed[0].includes("another organization"), `${s.length - failed.length} passed, ${failed.length} failed in ${buggy.seconds} s`);
} catch (e) { check('Buggy app: only the tenant test fails', false, buggy.stderr.slice(-400)); }

// 2. Fixed app
const fixed = run(['playwright', 'test', '--project=reference', '--reporter=json'], { PORT: '3102', APP_FIXED: '1' });
try {
  const s = summary(fixed);
  check('Fixed app: all reference tests pass', s.length === 3 && s.every((t) => t.ok), `${s.filter((t) => t.ok).length}/${s.length} passed in ${fixed.seconds} s`);
} catch (e) { check('Fixed app: all reference tests pass', false, fixed.stderr.slice(-400)); }

// 3. Receipt video
rmSync('receipts', { recursive: true, force: true });
const t0 = Date.now();
const rec = spawnSync(process.execPath, ['scripts/receipt.mjs'], { env: { ...process.env, PORT: '3103' }, encoding: 'utf8' });
const video = 'receipts/inv-142-tenant-leak.webm';
const size = existsSync(video) ? statSync(video).size : 0;
check('Receipt video records', rec.status === 0 && size > 100_000, rec.status === 0 ? `${(size / 1e6).toFixed(1)} MB in ${((Date.now() - t0) / 1000).toFixed(1)} s` : (rec.stderr || '').slice(-400));

// 4. Agents
const agents = ['planner', 'generator', 'healer'].every((a) => existsSync(`.claude/agents/playwright-test-${a}.md`));
const mcp = existsSync('.mcp.json') && readFileSync('.mcp.json', 'utf8').includes('run-test-mcp-server');
check('Agent definitions and .mcp.json present', agents && mcp, agents && mcp ? 'planner, generator, healer, playwright-test MCP server' : 'run: npx playwright init-agents --loop=claude');

for (const r of results) console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.name}  (${r.detail})`);

const pw = createRequire(import.meta.url)('@playwright/test/package.json').version;
writeFileSync('recorded-run.md', [
  '# qa-01 recorded run', '',
  `${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC, ${os.type()} ${os.release()}, Node ${process.versions.node}, Playwright ${pw}`, '',
  '| Check | Result | Detail |', '|---|---|---|',
  ...results.map((r) => `| ${r.name} | ${r.ok ? 'PASS' : 'FAIL'} | ${r.detail.replace(/\|/g, '/').replace(/\n/g, ' ')} |`), '',
  'The live agent steps (planner, generator, healer) need Claude Code and are not part of this check.', '',
].join('\n'));
console.log('Wrote recorded-run.md');
process.exit(results.every((r) => r.ok) ? 0 : 1);
