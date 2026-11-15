# Invoice list (INV-142) - test plan, as drafted

Fallback for the live demo: a plan like the one the planner drafts from TICKET.md and the seed.
Notice what's missing: nothing checks whose invoices are on the list.

## Setup
Seed: tests/seed.spec.ts (signed in as Acme, on /invoices).

## 1. Newest first, 5 per page
Steps: open the invoice list.
Expected: 5 rows; the Issued dates are in descending order.

## 2. Pagination
Steps: click "Next page", then "Previous page".
Expected: "Page 2 of N", then "Page 1 of N".
