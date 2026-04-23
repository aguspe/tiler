---
created: 2026-04-23T00:00:00Z
last_edited: 2026-04-23T00:00:00Z
---

# Tiler E2E Testability Analysis

How easy is it for a host application's Selenium / Cypress / Playwright suite to drive the Tiler engine? This document inventories the stable hooks Tiler exposes, scores each framework, and lists gaps that would close common e2e patterns.

## TL;DR

- **All three frameworks can drive Tiler today** with locator-quality CSS selectors and a small set of stable `data-*` hooks.
- **Most patterns require zero Tiler changes** — visiting routes, asserting widget content, and submitting the panel form work out of the box.
- **Drag-and-drop scenarios** are the only meaningfully hard surface. Selenium and Playwright can drive gridstack via its JS API (the path Tiler's own system tests use). Cypress needs the same JS-API approach because gridstack's drag layer doesn't respond to synthetic mouse events from any of these tools reliably.
- **One real gap**: gridstack ships its own dynamic `gs-*` attributes; tile DOM is created at runtime by gridstack, so before-init waits matter for every framework.
- **Score (1–5, higher = easier):** Selenium 4, Cypress 3, Playwright 5.

---

## Stable hook inventory

### Routes (host-app mounts at any path; defaults shown)

| Path | Purpose |
|---|---|
| `GET /tiler/dashboards` | Dashboard index |
| `GET /tiler/dashboards/:slug` | Dashboard show (the e2e entry point) |
| `GET /tiler/dashboards/:slug/panels/new` | Add-panel form |
| `POST /tiler/dashboards/:slug/panels` | Panel create (form / JSON / Turbo Stream) |
| `GET /tiler/dashboards/:slug/panels/:id/preview` | Single-panel preview frame |
| `PATCH /tiler/dashboards/:slug/layout` | Layout persistence (drag-drop callback) |

Slugs are URL-safe (alphanumeric + `-`). All routes nest under the engine's mount path — host apps know this prefix.

### Stable `data-*` attributes

These are the selectors a host-app e2e suite should target. They never change except by deliberate kit revision.

| Attribute | Carrier element | Purpose |
|---|---|---|
| `data-tiler-dashboard-id` | `.tiler-grid-stack` | Identifies which dashboard the grid renders |
| `data-tiler-layout-url` | `.tiler-grid-stack` | The PATCH endpoint for drag-drop persistence |
| `data-tiler-csrf` | `.tiler-grid-stack` | CSRF token for inline JS / synthetic XHR |
| `data-tiler-refresh` | `.tiler-grid-stack` | Refresh interval (seconds) when polling is enabled |
| `data-tiler-toggle-edit` | Edit-layout button | Enter/exit edit mode |
| `data-tiler-palette` | Palette `<aside>` | Palette container hook |
| `data-tiler-palette-widget` | Palette tile | One per registered widget type |
| `data-widget-type` | Palette tile | The widget identifier (e.g., `metric`, `meter`) |
| `data-default-w` / `data-default-h` | Palette tile | Default tile size for that widget |
| `data-default-config` | Palette tile | JSON-serialized default config (drop payload) |
| `data-tiler-rotate-interval` | Comments widget root | Rotation interval (seconds) for comments rotator |
| `data-tiler-clock` | Clock widget root | Hook for clock JS controller |
| `data-tiler-format` | Clock widget root | 12h vs 24h format |

### Stable element IDs (per-dashboard, per-panel)

| ID | Carrier element | Purpose |
|---|---|---|
| `tiler-grid-stack-<dashboard.id>` | `.grid-stack` | Turbo Stream target for new tiles |
| `tiler_panel_<panel.id>` | `<turbo-frame>` | Per-panel lazy-load frame |
| `tiler-comments-<panel.id>` | `.tiler-comments` div | Per-panel comments rotator container |
| `tiler-chart-<panel.id>` | `<canvas>` | Per-panel Chart.js canvas |

### Stable CSS classes

Every widget has its own root class, prefixed `tiler-`:

| Widget | Root class |
|---|---|
| Clock | `.tiler-clock` (with `.tiler-clock-time`, `.tiler-clock-date`) |
| Metric | `.tiler-metric` (`.tiler-metric-value`, `.tiler-metric-label`, `.tiler-metric-window`) |
| Number-with-delta | `.tiler-metric` + `.tiler-delta` (with `.tiler-delta-up/down/flat`) |
| Meter | `.tiler-meter` (`.tiler-meter-svg`, `.tiler-meter-value`) |
| Image | `.tiler-image-wrap` + `.tiler-image` |
| Comments | `.tiler-comments`, `.tiler-comment` (active class: `.tiler-comment-active`), `.tiler-comment-quote`, `.tiler-comment-name`, `.tiler-comment-avatar` |
| Iframe | `.tiler-iframe` |
| Text | `.tiler-text` (size variants `.tiler-text-{sm,md,lg,xl}`) |
| List | `.tiler-list`, `.tiler-list-item`, `.tiler-list-label`, `.tiler-list-value` |
| Table | `.tiler-table`, `.tiler-table-footer` |
| Status grid | `.tiler-status-grid`, `.tiler-status-tile`, `.tiler-status-{pass,warn,fail,unknown}` |
| Pie / Bar / Line chart | `<canvas id="tiler-chart-<panel.id>">` |

Panel chrome:

| Class | Purpose |
|---|---|
| `.tiler-panel` | Per-panel root |
| `.tiler-panel-header` | Header bar (carries widget label + edit link) |
| `.tiler-panel-body` | Widget content host |
| `.tiler-skeleton` | Placeholder shown while turbo-frame loads |
| `.tiler-editing` | Toggled on `.grid-stack` when in edit mode |
| `.tiler-editing-mode` | Toggled on `.tiler-dashboard-shell` when in edit mode |
| `.tiler-flash`, `.tiler-flash-{notice,alert}` | Flash messages after redirects |

### ARIA / accessibility hooks

- `<svg role="img" aria-valuemin/max/now>` on the meter widget — accessibility-tree readable
- `aria-label="Widget palette"` on the palette aside
- All form labels are programmatically associated (`<%= f.label :title %>` pattern)

### Gridstack runtime attributes

Gridstack adds `gs-id`, `gs-x`, `gs-y`, `gs-w`, `gs-h` to each `.grid-stack-item` after init. These are dynamic; don't assume stability across reloads, but they ARE stable within a session.

---

## Per-framework testability

### Selenium (4) — Score: 4 / 5

Strengths:
- Excellent CSS selector support; all Tiler `data-*` and class hooks are first-class
- WebDriver protocol can drive the gridstack JS API directly via `execute_script` — same pattern Tiler's own Capybara/Selenium tests use (see `test/system/dashboard_flow_test.rb`)
- ARIA / role assertions work natively via `By.css("svg[role='img']")` etc.

Friction:
- Pixel-precise drag-and-drop is unreliable in headless Chrome; must use the JS-API workaround pattern
- Turbo-frame lazy-load races can require explicit waits on the panel content selector (or set `Tiler.configuration.eager_panel_load = true` when running in test env)
- Multi-process driver setup is heavier than Cypress / Playwright

Recommended pattern (same as Tiler's own tests):
```ruby
driver.execute_script(<<~JS, panel_id)
  const id = arguments[0];
  const grid = document.querySelector('.grid-stack').gridstack;
  const node = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') == String(id));
  grid.update(node.el, { x: 5, y: 3, w: 4, h: 3 });
JS
```

### Cypress — Score: 3 / 5

Strengths:
- Strong `data-*` selector ergonomics: `cy.get('[data-widget-type="metric"]')`
- First-class auto-waiting reduces flake on Turbo-frame rendering
- Network-stub support (`cy.intercept`) makes asserting layout PATCH calls trivial

Friction:
- **Cypress's `cy.drag` plugin and synthetic mouse events do NOT trigger gridstack's drag-and-drop layer reliably.** Same root cause as Selenium's pixel-drag problem. Must call `gridstack.update(...)` via `cy.window().then(win => ...)`.
- **No cross-origin support** in Cypress for iframes (relevant for the `iframe` widget, less so for tiler's own dashboard)
- Cypress runs in a single Chrome tab — turbo-frame lazy-load behaves identically to a real browser, so tile content waits are needed (or set `eager_panel_load`)
- Cypress's session model conflicts with Rails CSRF in some test setups; Tiler exposes `data-tiler-csrf` to make the token reachable from spec code

Recommended pattern:
```javascript
cy.visit('/tiler/dashboards/demo')
cy.get('[data-tiler-toggle-edit]').click()
cy.window().then(win => {
  const grid = win.document.querySelector('.grid-stack').gridstack
  const node = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') === '5')
  grid.update(node.el, { x: 5, y: 3, w: 4, h: 3 })
})
cy.contains('.tiler-metric-value', '298')
```

Cypress also benefits from `data-cy` style selectors. Tiler does not currently emit `data-cy=` attributes by convention — host apps using Cypress would either (a) rely on the existing `data-tiler-*` and class hooks, or (b) wrap Tiler in a custom partial that adds `data-cy=` to whatever they care about.

### Playwright — Score: 5 / 5

Strengths:
- **Best-in-class drag-and-drop simulation.** `page.dragAndDrop()` and `page.mouse.move/down/up` produce real DOM events that gridstack will honor in many cases — though even Playwright struggles with gridstack's HTML5 drag layer, so the JS-API fallback is still recommended
- Auto-waiting on selectors makes Turbo-frame races trivial to handle
- Out-of-the-box ARIA / role support: `page.getByRole('img', { name: 'Gauge' })`
- Multi-browser (Chromium / Firefox / WebKit) — Tiler's CSS works across all three since it uses standard flexbox + grid
- Network interception via `page.route()` works with Tiler's PATCH layout calls
- First-class JavaScript API access via `page.evaluate()` — same pattern as Selenium's `execute_script`

Friction:
- None substantial. The same gridstack drag caveat applies, but Playwright's evaluate() is the cleanest of the three frameworks for the JS-API workaround
- HTML5 drag events occasionally need `page.locator(...).dragTo(...)` rather than `page.mouse.*` — minor

Recommended pattern:
```javascript
await page.goto('/tiler/dashboards/demo')
await page.locator('[data-tiler-toggle-edit]').click()
await page.evaluate(() => {
  const grid = document.querySelector('.grid-stack').gridstack
  const node = grid.engine.nodes.find(n => n.el.getAttribute('gs-id') === '5')
  grid.update(node.el, { x: 5, y: 3, w: 4, h: 3 })
})
await expect(page.locator('.tiler-metric-value')).toContainText('298')
```

For palette drag-drop:
```javascript
await page.evaluate(({ widgetType, x, y, w, h, config, csrf }) => {
  const fd = new FormData()
  fd.append('panel[widget_type]', widgetType)
  fd.append('panel[x]', x); fd.append('panel[y]', y)
  fd.append('panel[width]', w); fd.append('panel[height]', h)
  fd.append('panel[config]', config)
  return fetch(window.location.pathname + '/panels', {
    method: 'POST',
    headers: { 'X-CSRF-Token': csrf, Accept: 'text/vnd.turbo-stream.html' },
    body: fd, credentials: 'same-origin',
  })
}, { widgetType: 'metric', x: 0, y: 0, w: 3, h: 2, config: '{}', csrf: await page.locator('.tiler-grid-stack').getAttribute('data-tiler-csrf') })
```

---

## Common scenarios — feasibility matrix

| Scenario | Selenium | Cypress | Playwright | Notes |
|---|---|---|---|---|
| Visit dashboard, assert widget renders | ✅ | ✅ | ✅ | Use `.tiler-<widget>` class selectors |
| Click a panel's Edit link | ✅ | ✅ | ✅ | `.tiler-panel-header a[href*="edit"]` or text="Edit" |
| Submit the add-panel form | ✅ | ✅ | ✅ | Form submits as html (Turbo opt-out wired) |
| Drag-resize an existing panel | ✅ via JS API | ✅ via JS API | ✅ via JS API | Pixel drag unreliable in all three |
| Drop a palette widget into the grid | ✅ via JS API | ✅ via JS API | ✅ via JS API | Use `gridstack.dropped` simulation or direct POST |
| Assert layout PATCH fires | ✅ via log inspect | ✅ via `cy.intercept` | ✅ via `page.route` | Cypress + Playwright cleaner here |
| Assert flash notice after panel create | ✅ | ✅ | ✅ | Look for `.tiler-flash-notice` |
| Wait for turbo-frame content | Set `wait` arg | Auto-wait | Auto-wait | Or set `eager_panel_load` test config |
| Run axe-core accessibility scan | ✅ via `axe-core-capybara` | ✅ via `cypress-axe` | ✅ via `@axe-core/playwright` | Tiler exposes ARIA on meter; rest is layout-only |
| Test the comments rotator visibility | ✅ via class assertion | ✅ via `should('be.visible')` | ✅ via `getByText` | `.tiler-comment-active` swaps via inline JS |

---

## Gaps and recommendations

### G1: No top-level `data-tiler-version` attribute
A host-app suite that wants to skip a test on an old Tiler version has no easy hook. **Recommendation:** emit `<meta name="tiler-version" content="<%= Tiler::VERSION %>">` in the layout `<head>`. One line.

### G2: No `data-test-id` / `data-cy` convention
Tiler classes (`.tiler-metric-value`) are stable but coupled to styling. A class rename for redesign would break tests.
**Recommendation:** for any data-driven element, add a parallel `data-tiler-element="metric-value"` (or similar). Keeps style and test selectors decoupled.
Scope: ~15 partials. Low priority — current classes have been stable across the engine's lifetime.

### G3: Layout PATCH response shape changed (T-104) but no client lib documents it
Cypress / Playwright tests that intercept the PATCH and assert on the response body need to know it's now `{applied, skipped}` JSON.
**Recommendation:** publish a small section in README under "JSON contracts" listing the layout PATCH response and the panels#create JSON response. Documentation only.

### G4: Palette drag-drop has no documented JS handler API
Host apps wanting to add custom drop targets (e.g., "drop on trash to delete") don't have a pluggable hook.
**Recommendation:** out of scope for testability per se, but worth noting — Tiler's drop handler is inline in `app/views/tiler/dashboards/show.html.erb`. A future kit could expose a `tiler:panel:dropped` browser custom event that tests can listen for.

### G5: Comments rotator uses `setInterval` — Cypress/Playwright `clock` mocking needed
Time-based assertions on the rotator (e.g., "after 8s, second comment is active") are tricky without freezing time. Cypress has `cy.clock()`, Playwright has `page.clock`. Selenium has no built-in equivalent.
**Recommendation:** add `data-tiler-rotate-step` to the comments root — a counter incremented on each rotation tick. Tests assert the step value rather than waiting for real time.
Scope: 3 lines in `_comments.html.erb`.

### G6: No CI-friendly seed task documented for host apps
Host apps wiring Tiler into their CI need a reliable way to seed test data. Tiler has `tiler:seed` for the dummy app but doesn't document a host-app pattern.
**Recommendation:** README section: "Seeding Tiler from your host app's spec helpers" — example using `Tiler::Dashboard.create!` and `Tiler::Panel.create!` directly.

---

## Recommended test setup per framework

### Selenium / Capybara (Ruby host app)

```ruby
# rails_helper.rb
Capybara.default_max_wait_time = 10

# spec/system/dashboard_spec.rb
require 'rails_helper'

RSpec.describe 'Tiler dashboard', type: :system do
  before do
    @dashboard = Tiler::Dashboard.create!(name: 'CI')
    @dashboard.panels.create!(widget_type: 'clock', title: 'Clock',
                              x: 0, y: 0, width: 3, height: 2, config: '{}')
  end

  it 'renders the clock widget' do
    visit "/tiler/dashboards/#{@dashboard.slug}"
    expect(page).to have_css('.tiler-clock-time', wait: 5)
  end
end
```

### Cypress (any host stack)

```javascript
// cypress/e2e/tiler.cy.js
describe('Tiler dashboard', () => {
  beforeEach(() => {
    cy.task('db:seed:tiler', {
      dashboard: 'CI',
      panels: [{ widget_type: 'metric', config: { aggregation: 'count' } }]
    })
  })

  it('renders the metric widget', () => {
    cy.visit('/tiler/dashboards/ci')
    cy.get('.tiler-metric-value').should('exist')
  })

  it('asserts layout PATCH on drag', () => {
    cy.intercept('PATCH', '/tiler/dashboards/*/layout').as('layoutPatch')
    cy.visit('/tiler/dashboards/ci')
    cy.get('[data-tiler-toggle-edit]').click()
    cy.window().then(win => {
      const grid = win.document.querySelector('.grid-stack').gridstack
      const node = grid.engine.nodes[0]
      grid.update(node.el, { x: 5, y: 3 })
    })
    cy.wait('@layoutPatch').its('response.statusCode').should('eq', 200)
  })
})
```

### Playwright (any host stack)

```javascript
// tests/tiler.spec.ts
import { test, expect } from '@playwright/test'

test('renders the metric widget', async ({ page }) => {
  await page.goto('/tiler/dashboards/ci')
  await expect(page.locator('.tiler-metric-value')).toBeVisible()
})

test('asserts layout PATCH on drag', async ({ page }) => {
  const layoutPatch = page.waitForResponse(r =>
    r.url().includes('/layout') && r.request().method() === 'PATCH'
  )
  await page.goto('/tiler/dashboards/ci')
  await page.locator('[data-tiler-toggle-edit]').click()
  await page.evaluate(() => {
    const grid = document.querySelector('.grid-stack').gridstack
    const node = grid.engine.nodes[0]
    grid.update(node.el, { x: 5, y: 3 })
  })
  const res = await layoutPatch
  expect(res.status()).toBe(200)
})
```

---

## Summary scoring rationale

| Criterion | Selenium | Cypress | Playwright |
|---|---|---|---|
| Selector ergonomics | 4 | 5 | 5 |
| Auto-waiting | 3 (manual waits) | 5 | 5 |
| JS API access (gridstack workaround) | 4 | 4 | 5 |
| Network interception | 3 (proxy needed) | 5 | 5 |
| Real drag-drop | 3 | 2 | 4 |
| Iframe / cross-origin | 4 | 1 | 4 |
| Rails/Capybara native fit | 5 | 3 | 3 |
| Total (out of 35) | 26 (~74%) | 25 (~71%) | 31 (~89%) |

Score normalized to 1–5: Selenium 4, Cypress 3, Playwright 5.

---

## Bottom line

**Tiler is e2e-test-friendly today.** The class hierarchy is stable, the `data-*` hooks are well-named, ARIA is present on meter, and the gridstack drag-drop limitation is universal (not Tiler-specific). All three frameworks can drive Tiler with minimal setup. Playwright wins on raw ergonomics; Selenium wins for Ruby/Rails host apps that already have Capybara; Cypress trails slightly on drag-drop but excels at network interception and the dev-loop developer experience.

Closing G1, G2, and G5 (small, mostly markup-only changes) would push all three frameworks to ~95% effortless. G3 and G6 are documentation-only.
