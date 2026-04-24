# Tiler + Cypress

A starter for driving a Tiler dashboard from a Cypress suite in your own app.
The three example tests show the patterns you'll re-use; copy them into your
suite, then write whatever assertions your dashboard cares about.

## 1. Mount Tiler in your Rails app

In your app's `Gemfile`:

```ruby
gem "tiler"
```

Then:

```bash
bundle install
bin/rails generate tiler:install      # mounts engine + writes initializer
bin/rails db:migrate
bin/rails tiler:seed                  # creates the "demo" dashboard
bin/rails server                      # default :3000
```

Visit `http://127.0.0.1:3000/tiler/dashboards/demo` — you should see a grid
of panels (clock, metric, chart, list, table, etc.).

> Don't have a Rails app yet? You can run the dummy app shipped with this
> repo: `bundle install && bin/rails db:migrate && bin/rails tiler:seed && bin/rails server`.

## 2. Install Cypress

```bash
cd examples/cypress
npm install
```

## 3. Run

Point `CYPRESS_BASE_URL` at the host running Tiler. `CYPRESS_DASHBOARD_SLUG`
defaults to `demo` (matches `bin/rails tiler:seed`).

Headless:

```bash
CYPRESS_BASE_URL=http://127.0.0.1:3000 \
CYPRESS_DASHBOARD_SLUG=demo \
npx cypress run
```

Open the runner:

```bash
npx cypress open
```

## What the tests show

| Pattern | Selector | Why |
|---|---|---|
| Wait for the grid | `.tiler-grid-stack` | Confirms the dashboard view loaded |
| Find any panel | `.grid-stack-item[gs-id]` | Each persisted panel carries its DB id |
| Read widget content | `.tiler-clock-time` / `.tiler-metric-value` / etc. | Per-widget class hook, stable across releases |
| Open the edit drawer | `[data-tiler-panel-header]` → `[data-tiler-drawer].is-open` | Click the header; assert drawer appears in-page |

Use these as starting points; add assertions for your own panels by querying
the same `.tiler-<widget-type>*` hooks.

## Files

- `package.json` — Cypress dependency
- `cypress.config.js` — base URL + env defaults
- `cypress/e2e/dashboard.cy.js` — three example tests
