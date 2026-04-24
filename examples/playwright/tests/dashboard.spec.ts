// Tiler dashboard — Playwright example.
//
// Three small, copy-pastable patterns for driving a Tiler dashboard from a
// Playwright suite in your own app. They are not exhaustive tests of Tiler
// itself — see this repo's `test/system/*` for that.
//
// Setup is in the README: install Tiler in your Rails app, seed the demo
// dashboard, run the server, then point BASE_URL at it.
import { test, expect } from "@playwright/test";

const slug = process.env.DASHBOARD_SLUG ?? "demo";

test.describe("Tiler dashboard", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`/tiler/dashboards/${slug}`);
    // Wait for the grid container — every Tiler dashboard mounts a single
    // .tiler-grid-stack element.
    await expect(page.locator(".tiler-grid-stack")).toBeVisible();
  });

  test("dashboard renders at least one panel", async ({ page }) => {
    // Each persisted panel becomes a .grid-stack-item carrying gs-id="<panel.id>".
    await expect(page.locator(".grid-stack-item[gs-id]").first()).toBeVisible();
  });

  test("clock widget shows the current time", async ({ page }) => {
    // Widget partials emit class hooks like .tiler-clock-time / .tiler-metric-value.
    // Use those instead of structural selectors — they're stable across releases.
    await expect(page.locator(".tiler-clock-time")).toHaveText(/\d{1,2}:\d{2}:\d{2}/);
  });

  test("clicking a panel header opens the in-page edit drawer", async ({ page }) => {
    // Tiler edits panels in a slide-over drawer (no full-page nav). Click
    // anywhere on the panel header to open it; the drawer adds .is-open.
    const startUrl = page.url();
    await page.locator("[data-tiler-panel-header]").first().click();
    await expect(page.locator("[data-tiler-drawer].is-open")).toBeAttached();
    expect(page.url()).toBe(startUrl);
  });
});
