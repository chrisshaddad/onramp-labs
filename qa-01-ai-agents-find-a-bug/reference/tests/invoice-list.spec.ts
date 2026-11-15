import { test, expect, type Page } from '@playwright/test';

// Fallback: tests like the ones the generator writes from reference/specs/invoice-list.reviewed.md.

async function signInAs(page: Page, org: 'Acme' | 'Globex') {
  await page.goto('/login');
  await page.getByRole('button', { name: `Sign in as ${org}` }).click();
  await expect(page.getByRole('heading', { name: 'Invoices' })).toBeVisible();
}

test.describe('Invoice list (INV-142)', () => {
  test('shows 5 invoices per page, newest first', async ({ page }) => {
    await signInAs(page, 'Acme');
    const issued = await page.locator('tbody').getByRole('row').locator('td:nth-child(3)').allTextContents();
    expect(issued).toHaveLength(5);
    expect(issued).toEqual([...issued].sort().reverse());
  });

  test('pages forward and back', async ({ page }) => {
    await signInAs(page, 'Acme');
    await page.getByRole('link', { name: 'Next page' }).click();
    await expect(page.getByText(/^Page 2 of \d+$/)).toBeVisible();
    await page.getByRole('link', { name: 'Previous page' }).click();
    await expect(page.getByText(/^Page 1 of \d+$/)).toBeVisible();
  });

  // Added in plan review: the ticket says "my organization's invoices".
  test("never shows another organization's invoices", async ({ page }) => {
    await signInAs(page, 'Acme');
    const numbers: string[] = [];
    while (true) {
      numbers.push(...(await page.locator('tbody').getByRole('row').locator('td:first-child').allTextContents()));
      const next = page.getByRole('link', { name: 'Next page' });
      if (!(await next.isVisible())) break;
      await next.click();
    }
    expect(numbers.filter((n) => !n.startsWith('ACM-'))).toEqual([]);
  });
});
