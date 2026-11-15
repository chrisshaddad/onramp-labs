# Invoice list (INV-142) - test plan, after review

Same plan with the case the group adds in review. The ticket says "my organization's invoices",
so another organization's invoices must never appear, on any page.

## Setup
Seed: tests/seed.spec.ts (signed in as Acme, on /invoices).

## 1. Newest first, 5 per page
Steps: open the invoice list.
Expected: 5 rows; the Issued dates are in descending order.

## 2. Pagination
Steps: click "Next page", then "Previous page".
Expected: "Page 2 of N", then "Page 1 of N".

## 3. Only the signed-in organization's invoices (added in review)
Steps: signed in as Acme, read the invoice numbers on every page.
Expected: every number starts with "ACM-". No Globex invoice ("GLX-") on any page.
