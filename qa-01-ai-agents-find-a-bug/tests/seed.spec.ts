import { test, expect } from '@playwright/test';

// Seed for the planner and generator: a signed-in Acme user on the invoice list.
test.describe('Invoice list', () => {
  test('seed', async ({ page }) => {
    await page.goto('/login');
    await page.getByRole('button', { name: 'Sign in as Acme' }).click();
    await expect(page.getByRole('heading', { name: 'Invoices' })).toBeVisible();
  });
});
