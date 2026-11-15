# qa-01-ai-agents-find-a-bug

Live demo for the S13 deck, slide "Demo - AI agents find the bug". Playwright's test agents (planner, generator, healer) run inside Claude Code against a small invoices app with a planted bug: the invoice list has no tenant filter, so Acme sees Globex invoices. The agents get the ticket, never the buggy code. The run ends with a captioned video receipt.

Unlike the database and Docker labs, this one runs on the host, not in a container: Claude Code drives a real Chrome window on the instructor's screen through Playwright's MCP server.

## Setup (once)

Prerequisites: Node 20 or later, Google Chrome, Claude Code (desktop app or CLI).

```
cd qa-01-ai-agents-find-a-bug
npm ci
npx playwright install ffmpeg
npm run verify
```

- `npx playwright install ffmpeg` downloads the small video encoder that `page.screencast` needs. The tests use your installed Chrome (`channel: 'chrome'`), so no browser download.
- `npm run verify` should print four PASS lines (about 25 s) and writes `recorded-run.md`.
- The agent definitions (`.claude/agents/`) and `.mcp.json` are committed. After a Playwright upgrade, regenerate them with `npx playwright init-agents --loop=claude` and review the diff: it overwrites `.mcp.json`.

## Before a session

```
npm run reset
npm start
```

Leave `npm start` running (http://localhost:3100). Open Claude Code in this folder, so it picks up the agents and the MCP server. In the desktop app, open the folder as the session's working folder; with the CLI, run `claude` from here.

## Run sheet (about 15 minutes, same text as the slide's speaker notes)

| # | Do | Expected |
|---|---|---|
| 1 | Open http://localhost:3100, click "Sign in as Acme" | The invoice list. Don't point out the GLX rows. |
| 2 | Show `TICKET.md` | INV-142, four acceptance criteria |
| 3 | In Claude Code: *Use the playwright-test-planner agent to plan tests for the invoice list in TICKET.md. Use tests/seed.spec.ts. Save the plan as specs/invoice-list.md.* | A Chrome window opens and the agent explores; a Markdown plan appears in `specs/` |
| 4 | Open the plan. Ask the group: what's missing? | Someone says another org's invoices must never appear. Add that scenario to the plan. |
| 5 | *Use the playwright-test-generator agent to write tests for every scenario in specs/invoice-list.md.* | Test files in `tests/` |
| 6 | `npm test` | The tenant test fails and lists GLX-2005, GLX-2004, ... |
| 7 | *Use the playwright-test-healer agent to fix the failing test.* | It proposes changing the assertion or marking the test `test.fixme()`. Refuse: the app is wrong, not the test. |
| 8 | `npm run receipt`, then open `receipts/inv-142-tenant-leak.webm` in Chrome | A 19 s video: chapter cards, highlighted clicks, Globex rows outlined in amber |
| 9 | Optional: stop the app, `npm run start:fixed`, `npm test` | All green: the same test passes once the query filters by org |

The agents' output varies run to run: exact wording, file names and number of tests differ. That's expected.

## Fallback

If the live run drifts or runs long:

- Plans: `reference/specs/invoice-list.plan.md` (as drafted, missing the tenant case) and `invoice-list.reviewed.md` (after review).
- Tests: `npm run test:reference` runs the reviewed tests. Expected: 2 passed, 1 failed (`never shows another organization's invoices`), with the received list ending in `GLX-2001`.
- The receipt script doesn't use AI, so step 8 always works.

## What's in the folder

| Path | What it is |
|---|---|
| `app/server.mjs` | The invoices app, no dependencies. `--fixed` adds the tenant filter. |
| `TICKET.md` | The ticket the agents work from |
| `tests/seed.spec.ts` | Seed test: signed in as Acme on the invoice list. The planner and generator start from it. |
| `specs/` | Where the planner saves plans |
| `.claude/agents/`, `.mcp.json` | Playwright's agent definitions for Claude Code, and its test MCP server |
| `reference/` | Fallback plans and tests |
| `scripts/receipt.mjs` | Records the video receipt with `page.screencast` (chapters, action highlights) |
| `scripts/reset.mjs` | Removes what the agents wrote last time (keeps the seed) |
| `scripts/verify.mjs` | Checks the lab without the AI part |

## Troubleshooting

- **PowerShell: "npx.ps1 cannot be loaded because running scripts is disabled":** use `npm.cmd` and `npx.cmd` (for example `npx.cmd playwright install ffmpeg`), or allow scripts for your user with `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.
- **Port 3100 in use:** set `PORT` (PowerShell: `$env:PORT=3200; npm start`) and use the same value for `npm test`.
- **"Executable doesn't exist ... ffmpeg":** run `npx playwright install ffmpeg`.
- **"Chromium distribution 'chrome' is not found":** install Google Chrome, or run `npx playwright install chromium` and remove `channel: 'chrome'` from `playwright.config.ts`.
- **Claude Code doesn't list the playwright-test agents:** it was opened in another folder. Open it in `qa-01-ai-agents-find-a-bug`.
- **`npm test` passes when it should fail:** a fixed server is still running on 3100. Stop it and run `npm start`.

## Verified

Playwright 1.65.1 with Chrome for Testing 153, Node 22, on Linux (cloud sandbox), November 15, 2026: `npm run verify` 4/4 PASS. Reference tests on the buggy app: 2 passed, 1 failed in 3.2 s; on the fixed app: 3/3 in 2.8 s. Receipt: 19.1 s video, 1280x720, 1.6 MB. The live agent steps (3 to 7) need Claude Code and were not run here.
