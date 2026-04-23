import { test, expect } from "@playwright/test";

const slug = process.env.DASHBOARD_SLUG ?? "demo";

test.describe("Tiler dashboard", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(`/tiler/dashboards/${slug}`);
    await expect(page.locator(".tiler-grid-stack")).toBeVisible();
  });

  test("renders the grid with at least one panel", async ({ page }) => {
    await expect(page.locator(".grid-stack-item").first()).toBeVisible();
    const count = await page.locator(".grid-stack-item").count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test("renders the clock widget with a current time", async ({ page }) => {
    const time = page.locator(".tiler-clock-time");
    await expect(time).toBeVisible();
    await expect(time).toHaveText(/\d{1,2}:\d{2}:\d{2}/);
  });

  test("drives a panel move via the gridstack JS API; PATCH layout fires", async ({ page }) => {
    const patchPromise = page.waitForResponse(
      (r) => r.url().includes(`/tiler/dashboards/${slug}/layout`) && r.request().method() === "PATCH"
    );

    await page.locator("[data-tiler-toggle-edit]").click();

    const panelId = await page.locator(".grid-stack-item[gs-id]").first().getAttribute("gs-id");
    expect(panelId).not.toBeNull();

    await page.evaluate(
      ({ id, x, y }) => {
        // @ts-expect-error gridstack hangs off the .grid-stack element at runtime
        const grid = document.querySelector(".grid-stack").gridstack;
        const node = grid.engine.nodes.find((n: any) => n.el.getAttribute("gs-id") === String(id));
        grid.update(node.el, { x, y });
      },
      { id: panelId, x: 4, y: 8 }
    );

    const res = await patchPromise;
    expect(res.status()).toBe(200);

    await expect(page.locator(`.grid-stack-item[gs-id='${panelId}']`)).toHaveAttribute("gs-x", "4");
    await expect(page.locator(`.grid-stack-item[gs-id='${panelId}']`)).toHaveAttribute("gs-y", "8");

    // Reload — coords persisted by the server should survive.
    await page.reload();
    await expect(page.locator(`.grid-stack-item[gs-id='${panelId}']`)).toHaveAttribute("gs-x", "4");
    await expect(page.locator(`.grid-stack-item[gs-id='${panelId}']`)).toHaveAttribute("gs-y", "8");
  });
});
