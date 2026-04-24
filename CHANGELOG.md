# Changelog

## 0.1.0 — 2026-04-24

First release.

### Engine

- Mountable Rails engine with Dashboard / Panel / DataSource / DataRecord
  models, all under the `tiler_` table prefix.
- Configurable authorization via `Tiler.configuration` lambdas
  (`authorize_view` / `authorize_manage`) inheriting from the host's
  `ApplicationController`.
- Install generator (`rails g tiler:install`).
- Webhook ingestion endpoint with per-source token auth.

### Widgets (14 built-in)

- `metric`, `number_with_delta` (inline sparkline), `meter`, `clock`,
  `text`, `status_grid`, `comments`, `list`, `table` (structured
  `columns:[{label, column, num?, agg?}]` + sticky header), `line_chart`
  (structured `series:[{label, column, agg, color?}]`, `1h | 1d | 1w`
  buckets), `bar_chart` (per-bar palette + `limit`), `pie_chart`
  (limit + "Other" overflow + right-side legend at width≥4), `image`,
  `iframe` (fixed sandbox).
- Catalog parity test locks every widget's default size + banned config
  keys against the design system.
- Per-widget color override on the edit form: `config.color` (single hex)
  + `config.palette` (array). Charts read `palette > color > default`.

### Custom widgets (three paths)

- **Ruby host app**: drop a self-registering Widget class in `app/widgets/`,
  picked up on boot + dev reload (`bin/rails generate tiler:widget weather`).
- **Gem-pack**: distribute community widgets as their own Ruby gems —
  documented in `WIDGETS.md`.
- **No-code (Liquid)**: `Settings → Custom widgets` lets non-engineers
  define widgets through a sandboxed Liquid template + JSON query
  definition. Auto-registers under `user_<slug>`. Whitelisted
  aggregations only; alphanumeric column names; template length capped.

### Dashboard UX

- 12-column gridstack with full edge + corner resize, palette → drop
  creates panels, click any tile header to edit in a slide-over drawer.
- Inline rename: double-click the dashboard title to edit it in place.
- Hover-to-delete dashboards on the index, modal-confirmed.
- Empty-state overlay sitting on the actual drop surface.
- Mobile responsive: gridstack collapses to one column under 720px;
  drawer fills the viewport.
- TV mode hides chrome for wall-mounted displays.

### Theming

- Per-dashboard 4-token theme: `page_bg`, `tile_bg`, `tile_header_bg`,
  `gutter_bg` emit inline CSS custom properties on `.tiler-dashboard`.
- Reset-theme button in Settings.

### Presets (CLI)

- `bin/rails tiler:preset:default` — generic, every widget on one grid.
- `bin/rails tiler:preset:test_automation` — Allure-style QA cockpit.
- `bin/rails tiler:preset:commerce` — shop ops dashboard (revenue, AOV,
  conversion, top products).
- `bin/rails tiler:preset` lists what's available.

### Examples

Five copy-pastable starters under `examples/`: rails-host-app, json-ingest,
selenium-ruby-rspec, cypress, playwright. Each e2e starter walks through
mounting Tiler in your own app and pointing the framework at the live
dashboard via env vars.

### Engineering

- 342 unit tests + 176 system tests, all green.
- CI runs lint + unit + system + each example suite against the dummy app.
