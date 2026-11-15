// Invoices demo app for the "Demo - AI agents find the bug" slide.
// No dependencies: Node's own http module and in-memory data.
//
// Run:        node app/server.mjs           (planted bug: no tenant filter)
// Fixed run:  node app/server.mjs --fixed   (the list is filtered by org)
// Port:       3100, or set PORT.
import { createServer } from 'node:http';

const PORT = Number(process.env.PORT ?? 3100);
const FIXED = process.argv.includes('--fixed') || process.env.APP_FIXED === '1';
const PAGE_SIZE = 5;

const ORGS = { acme: 'Acme', globex: 'Globex' };

// Two tenants in one table, like a real multi-tenant app. Dates interleave on purpose.
const INVOICES = [
  { number: 'ACM-1007', org: 'acme',   customer: 'Northwind Traders', issued: '2026-11-12', totalCents: 129_000 },
  { number: 'GLX-2005', org: 'globex', customer: 'Initech',           issued: '2026-11-10', totalCents: 87_500 },
  { number: 'ACM-1006', org: 'acme',   customer: 'Contoso',           issued: '2026-11-08', totalCents: 45_000 },
  { number: 'ACM-1005', org: 'acme',   customer: 'Fabrikam',          issued: '2026-11-03', totalCents: 310_250 },
  { number: 'GLX-2004', org: 'globex', customer: 'Umbrella Corp',     issued: '2026-10-30', totalCents: 12_000 },
  { number: 'ACM-1004', org: 'acme',   customer: 'Tailspin Toys',     issued: '2026-10-27', totalCents: 64_990 },
  { number: 'GLX-2003', org: 'globex', customer: 'Hooli',             issued: '2026-10-21', totalCents: 230_000 },
  { number: 'ACM-1003', org: 'acme',   customer: 'Wide World Importers', issued: '2026-10-15', totalCents: 18_400 },
  { number: 'ACM-1002', org: 'acme',   customer: 'Adventure Works',   issued: '2026-10-02', totalCents: 99_000 },
  { number: 'GLX-2002', org: 'globex', customer: 'Stark Industries',  issued: '2026-09-25', totalCents: 41_300 },
  { number: 'ACM-1001', org: 'acme',   customer: 'Northwind Traders', issued: '2026-09-18', totalCents: 76_000 },
  { number: 'GLX-2001', org: 'globex', customer: 'Initech',           issued: '2026-09-11', totalCents: 5_500 },
];

// The ticket: list invoices for the current org, newest first, paginated.
function listInvoices(org, page) {
  const rows = FIXED
    ? INVOICES.filter((inv) => inv.org === org)
    : INVOICES; // BUG (planted): the tenant filter is missing, so every org sees every invoice
  const sorted = [...rows].sort((a, b) => b.issued.localeCompare(a.issued));
  const pages = Math.max(1, Math.ceil(sorted.length / PAGE_SIZE));
  const current = Math.min(Math.max(1, page), pages);
  return { items: sorted.slice((current - 1) * PAGE_SIZE, current * PAGE_SIZE), page: current, pages };
}

const money = (cents) => `$${(cents / 100).toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

const layout = (title, body) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>${esc(title)}</title>
<style>
  body { font-family: Arial, sans-serif; background: #f3f3f3; color: #1c2d44; margin: 0; }
  header { background: #1c2d44; color: #fff; padding: 12px 24px; display: flex; justify-content: space-between; align-items: center; }
  main { max-width: 760px; margin: 32px auto; background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 24px; }
  table { width: 100%; border-collapse: collapse; margin: 16px 0; }
  th { text-align: left; background: #1c2d44; color: #fff; padding: 8px; }
  td { padding: 8px; border-bottom: 1px solid #d0d7e1; }
  td.total, th.total { text-align: right; }
  nav { display: flex; gap: 16px; align-items: center; }
  a, button { color: #1c2d44; font-size: 16px; }
  button { background: #6cb6dd; border: 0; border-radius: 6px; padding: 10px 16px; cursor: pointer; color: #fff; }
  header button { background: transparent; border: 1px solid #fff; padding: 6px 12px; }
</style></head><body>${body}</body></html>`;

function loginPage() {
  return layout('Sign in - Invoices', `
<main>
  <h1>Sign in</h1>
  <p>Demo accounts, no password.</p>
  <form method="post" action="/login"><input type="hidden" name="org" value="acme"><button type="submit">Sign in as Acme</button></form>
  <p></p>
  <form method="post" action="/login"><input type="hidden" name="org" value="globex"><button type="submit">Sign in as Globex</button></form>
</main>`);
}

function invoicesPage(org, page) {
  const { items, page: current, pages } = listInvoices(org, page);
  const rows = items.map((inv) => `
      <tr><td>${esc(inv.number)}</td><td>${esc(inv.customer)}</td><td>${esc(inv.issued)}</td><td class="total">${money(inv.totalCents)}</td></tr>`).join('');
  const prev = current > 1 ? `<a href="/invoices?page=${current - 1}">Previous page</a>` : '';
  const next = current < pages ? `<a href="/invoices?page=${current + 1}">Next page</a>` : '';
  return layout(`Invoices - ${ORGS[org]}`, `
<header><span>Signed in as <strong>${esc(ORGS[org])}</strong></span>
  <form method="post" action="/logout"><button type="submit">Sign out</button></form></header>
<main>
  <h1>Invoices</h1>
  <table>
    <thead><tr><th>Number</th><th>Customer</th><th>Issued</th><th class="total">Total</th></tr></thead>
    <tbody>${rows}
    </tbody>
  </table>
  <nav aria-label="Pagination">${prev}<span>Page ${current} of ${pages}</span>${next}</nav>
</main>`);
}

function readBody(req) {
  return new Promise((resolve) => {
    let data = '';
    req.on('data', (c) => { data += c; });
    req.on('end', () => resolve(new URLSearchParams(data)));
  });
}

function orgFrom(req) {
  const match = /(?:^|;\s*)org=(\w+)/.exec(req.headers.cookie ?? '');
  return match && ORGS[match[1]] ? match[1] : null;
}

const send = (res, status, body, headers = {}) => {
  res.writeHead(status, { 'content-type': 'text/html; charset=utf-8', ...headers });
  res.end(body);
};

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const org = orgFrom(req);

  if (req.method === 'GET' && url.pathname === '/') return send(res, 302, '', { location: org ? '/invoices' : '/login' });
  if (req.method === 'GET' && url.pathname === '/login') return send(res, 200, loginPage());
  if (req.method === 'POST' && url.pathname === '/login') {
    const chosen = (await readBody(req)).get('org');
    if (!ORGS[chosen]) return send(res, 400, 'Unknown org');
    return send(res, 303, '', { location: '/invoices', 'set-cookie': `org=${chosen}; Path=/; HttpOnly; SameSite=Lax` });
  }
  if (req.method === 'POST' && url.pathname === '/logout') {
    return send(res, 303, '', { location: '/login', 'set-cookie': 'org=; Path=/; Max-Age=0' });
  }
  if (req.method === 'GET' && url.pathname === '/invoices') {
    if (!org) return send(res, 302, '', { location: '/login' });
    return send(res, 200, invoicesPage(org, Number(url.searchParams.get('page') ?? 1)));
  }
  if (req.method === 'GET' && url.pathname === '/health') return send(res, 200, 'ok', { 'content-type': 'text/plain' });
  return send(res, 404, 'Not found');
});

server.listen(PORT, () => {
  console.log(`Invoices app on http://localhost:${PORT} (${FIXED ? 'fixed' : 'planted bug: no tenant filter'})`);
});
