# Tiler E2E — Cypress

Minimal Cypress suite driving a running Tiler dashboard.

## Setup

```bash
cd examples/cypress
npm install
```

## Run

Point `CYPRESS_BASE_URL` at your dashboard host. Defaults to `http://127.0.0.1:3131` (the Tiler dummy app).

Headless:
```bash
CYPRESS_BASE_URL=http://127.0.0.1:3131 \
CYPRESS_DASHBOARD_SLUG=demo \
npx cypress run
```

Open the runner:
```bash
npx cypress open
```

## Files

- `package.json` — cypress dependency
- `cypress.config.js` — base URL + env defaults
- `cypress/e2e/dashboard.cy.js` — three example tests
