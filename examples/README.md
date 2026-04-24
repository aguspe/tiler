# Tiler Examples

Five small, copy-pastable starters for using Tiler from your own app.

| Example | Stack | Use it for |
|---|---|---|
| [`rails-host-app/`](./rails-host-app) | Ruby on Rails | Mount Tiler in any Rails 7+ host application |
| [`json-ingest/`](./json-ingest) | curl / Node / Python / Bash | Push data into Tiler from any system that speaks HTTP+JSON |
| [`selenium-ruby-rspec/`](./selenium-ruby-rspec) | Selenium + Ruby + RSpec | Driving a Tiler dashboard from a Ruby/Selenium suite in your app |
| [`cypress/`](./cypress) | Cypress | Driving a Tiler dashboard from a Cypress suite in your app |
| [`playwright/`](./playwright) | Playwright | Driving a Tiler dashboard from a Playwright suite in your app |

## Where to start

- **Adding Tiler to your Rails app** → [`rails-host-app/`](./rails-host-app), then [`json-ingest/`](./json-ingest) once you're ready to wire in real data.
- **Pushing data from a non-Rails system** → [`json-ingest/`](./json-ingest) covers webhook ingestion in shell, Node, and Python.
- **Driving Tiler from your existing test framework** → pick the runner your team already uses; each README walks through Tiler install + how to point the runner at your dashboard.

## Set Tiler up once, drive it from anywhere

The three e2e starters all assume the same setup — install Tiler in your
Rails app, run `bin/rails tiler:seed` to create a `demo` dashboard, then
point the framework at `http://127.0.0.1:3000/tiler/dashboards/demo`.

```bash
# In your Rails app's Gemfile:
gem "tiler"

bundle install
bin/rails generate tiler:install
bin/rails db:migrate
bin/rails tiler:seed
bin/rails server
```

(No Rails app yet? You can run the dummy app shipped with this repo:
`bundle install && bin/rails db:migrate && bin/rails tiler:seed && bin/rails server`.)

## Stable selectors used by every starter

| Selector | What it represents |
|---|---|
| `.tiler-grid-stack` | The dashboard grid container (one per page) |
| `.grid-stack-item[gs-id]` | A persisted panel; `gs-id` is its DB id |
| `.tiler-<widget-type>` / `.tiler-<widget-type>-*` | Per-widget class hooks (e.g. `.tiler-clock-time`) |
| `[data-tiler-panel-header]` | Click to open the in-page edit drawer |
| `[data-tiler-drawer]` (`.is-open`) | The slide-over edit drawer |
| `[data-tiler-add-panel]` | Toggles the widget palette |

The example tests use these instead of structural selectors so they survive
release-to-release styling changes.

## See also

- Root [`README.md`](../README.md) — Tiler installation + configuration
- [`../WIDGETS.md`](../WIDGETS.md) — extending Tiler with your own widgets
- [`../context/refs/tiler-e2e-testability.md`](../context/refs/tiler-e2e-testability.md) — full per-framework testability analysis
