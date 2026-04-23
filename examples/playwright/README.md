# Tiler E2E — Playwright

Minimal Playwright suite driving a running Tiler dashboard.

## Setup

```bash
cd examples/playwright
npm install
npx playwright install chromium
```

## Run

Point `BASE_URL` at your dashboard host. Defaults to `http://127.0.0.1:3131` (the Tiler dummy app).

```bash
BASE_URL=http://127.0.0.1:3131 \
DASHBOARD_SLUG=demo \
npx playwright test
```

Or open the UI runner:
```bash
npx playwright test --ui
```

## Files

- `package.json` — playwright dependency
- `playwright.config.ts` — base URL + browser config
- `tests/dashboard.spec.ts` — three example tests
