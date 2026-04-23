# Tiler Examples

Five minimal, self-contained examples covering installation, data ingestion, and end-to-end testing.

| Example | Stack | Purpose |
|---|---|---|
| [`rails-host-app/`](./rails-host-app) | Ruby on Rails | Mount Tiler in any Rails 7+ host application |
| [`json-ingest/`](./json-ingest) | curl / Node / Python / Bash | Push data into Tiler from any system that speaks HTTP+JSON |
| [`selenium-ruby-rspec/`](./selenium-ruby-rspec) | Selenium + Ruby + RSpec | E2E tests for Rails host apps already using Capybara |
| [`cypress/`](./cypress) | Cypress | E2E tests, JS-first dev loop, network interception |
| [`playwright/`](./playwright) | Playwright | E2E tests, multi-browser CI |

## Where to start

- **Adding Tiler to your Rails app** → start with [`rails-host-app/`](./rails-host-app), then [`json-ingest/`](./json-ingest) once you're ready to wire in real data.
- **Pushing data from a non-Rails system** → [`json-ingest/`](./json-ingest) covers webhook ingestion in shell, Node, and Python.
- **Adding e2e coverage** → pick the framework your team already uses; all three drive the same dashboard via the same stable hooks.

## What every e2e example demonstrates

1. **Dashboard renders** — visit, assert at least one panel
2. **Widget content** — assert the clock widget shows a current-looking time
3. **Drag-drop layout change** — drive gridstack via its JS API, verify PATCH layout fires and persists across reload

All three e2e examples assume a running Tiler dashboard at `http://127.0.0.1:3131/tiler/dashboards/demo` (the dummy app shipped in this repo). Override via env var.

## See also

- [`../context/refs/tiler-e2e-testability.md`](../context/refs/tiler-e2e-testability.md) — full testability analysis: stable selector inventory, per-framework scoring, and known gaps
- Root [`README.md`](../README.md) — Tiler installation and configuration overview
