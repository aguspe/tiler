# Tiler

Plug-and-play dashboards for Rails. Configurable widgets, JSON data sources, webhook ingestion, Turbo-powered live panels. Inspired by [Smashing](https://github.com/Smashing/smashing).

## Features

- 📊 **14 built-in widgets**: metric, number-with-delta (sparkline), meter, clock, text, status grid, comments, list, table, line / bar / pie charts, image, iframe
- 🔌 **Widget registry, three ways**:
  - drop a Ruby class in `app/widgets/` (auto-loaded + dev-reloaded)
  - publish a Ruby gem that registers on its own railtie
  - **no-code**: define widgets through Settings using a sandboxed Liquid template
- 🎨 **Per-dashboard theme**: 4 token overrides (page / tile / tile header / gutter) shown live via inline CSS custom properties
- 🖍️ **Per-panel color override**: charts read `palette` (array) or `color` (single) from `panel.config`; line charts also accept per-series colors
- 🪟 **Drag, resize, drop**: gridstack-driven layout (1–12 col grid), full edge + corner resize, palette → drop creates panels, click any tile header to edit in a slide-over drawer
- ✏️ **Inline rename**: double-click the dashboard title to edit it in place; Esc to cancel
- 🗑️ **Hover-to-delete**: each dashboard card shows a × on hover with a confirm modal
- 🗄️ **Schemaless data sources**: JSON payloads, schema is descriptive not enforced
- 📥 **Multi-channel ingestion**: webhook (HMAC-style token), manual entry, CSV import
- ⚡ **Turbo Frames**: lazy-loaded panels, optional auto-refresh, drawer-based editing
- 📺 **TV mode**: per-dashboard toggle that hides chrome — wall-mount friendly
- 📱 **Mobile responsive**: gridstack collapses to one column under 720px; drawer fills viewport
- 🔐 **Plug into your auth**: inherits from your `ApplicationController`, configurable `authorize_view` / `authorize_manage` lambdas
- 💎 **Mountable Rails engine**: one install generator, mount anywhere

## Install

Add to your `Gemfile`:

```ruby
gem "tiler"
```

Then:

```bash
bundle install
bin/rails generate tiler:install
bin/rails db:migrate
bin/rails server
```

Visit `/tiler`.

To load a demo dashboard:

```bash
bin/rails tiler:seed
```

## Configure

`config/initializers/tiler.rb` is written by the install generator:

```ruby
Tiler.configure do |config|
  config.parent_controller = "::ApplicationController"  # inherits your auth
  config.authorize_view    = ->(ctrl) { ctrl.send(:user_signed_in?) }
  config.authorize_manage  = ->(ctrl) { ctrl.send(:current_user)&.admin? }
  config.default_refresh_seconds = 60
end
```

## Custom widgets

Three paths, depending on your audience.

### 1. Ruby (host app) — preferred for engineers

```bash
bin/rails generate tiler:widget weather
```

Creates a self-registering Widget + Query class + partial. The engine eager-loads everything under `app/widgets/**` on boot and re-loads on dev change — no initializer edit needed. Open Settings → Add Panel → **Weather**.

Full reference: [`WIDGETS.md`](./WIDGETS.md) — class attrs, query helpers, partial locals, `empty?` rules, color-override hooks, `example_*` fixtures, packaging widgets as gems.

### 2. Gem-pack — preferred for community widgets

```bash
bundle gem tiler-weather
```

Inside the gem's railtie, require + register your widget files. Host apps install with `bundle add tiler-weather` — nothing else. See "Packaging widgets as gems" in `WIDGETS.md`.

### 3. No-code (Liquid) — for non-engineers

Settings → **Custom widgets** → **New custom widget**. Define a slug, label, optional query (data source + aggregation), and a Liquid template. Saved widgets auto-register under `user_<slug>` and show up immediately in the Add Panel palette.

```liquid
<div class="tiler-metric">
  <div class="tiler-metric-value">{{ data.value | default: "—" }}</div>
  <div class="tiler-metric-label">{{ panel.title }}</div>
</div>
```

Liquid is sandboxed (no Ruby execution, no `{% include %}`); `query_definition` only allows whitelisted aggregations (`count`/`sum`/`avg`/`min`/`max`/`last`) against existing data sources. Live preview is built into the form.

## Ingest data via webhook

Every data source with `webhook` enabled gets a token shown on its detail page:

```bash
curl -X POST https://your-app.com/tiler/ingest/my_source \
  -H "X-Tiler-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{"status":"ok","duration":142.3}'
```

Send a JSON object (one record) or a JSON array (batch).

## Per-dashboard theme + per-panel colors

**Settings → Theme** exposes 4 color pickers per dashboard. Each maps to a CSS custom property that's emitted as inline style on `.tiler-dashboard`, so descendants inherit:

| Setting          | Token         | Paints                                |
| ---------------- | ------------- | ------------------------------------- |
| `page_bg`        | `--paper`     | Page background                       |
| `tile_bg`        | `--paper-2`   | Tile / panel surface                  |
| `tile_header_bg` | `--paper-3`   | Tile header strip + tags + hover bg   |
| `gutter_bg`      | `--border`    | Grid gutters between tiles            |

Per-panel chart color (visible on the edit form for opt-in widgets): `panel.config["color"]` (single hex) and/or `panel.config["palette"]` (array of hex). Line charts also accept `color` per `series` entry. Sanitization rejects anything that isn't `#rgb` / `#rrggbb` / `#rrggbbaa` silently.

## Model overview

- `Tiler::Dashboard` — `has_many :panels`, JSON `settings` (theme + tv_mode)
- `Tiler::Panel` — `widget_type`, `width`/`height`/`x`/`y`, `config` (JSON), `belongs_to :data_source`
- `Tiler::DataSource` — `schema_definition`, `ingestion_methods`, `webhook_token`
- `Tiler::DataRecord` — `payload` (JSON), `recorded_at`, `ingested_via`
- `Tiler::UserWidget` — runtime no-code widget definitions (Liquid template + safe query JSON)

All scoped under the `tiler_` table prefix to avoid colliding with host models.

## Extending

- **Custom parent controller** — set `config.parent_controller` so Tiler inherits your auth, layout, and before_actions.
- **Custom layout** — set `config.layout` to render Tiler pages inside your app chrome.
- **Multi-tenant** — override `Tiler::ApplicationController` in your host app to scope records by tenant.

## Examples

Working examples live under [`examples/`](./examples):

| Example | Use it for |
|---|---|
| [`rails-host-app/`](./examples/rails-host-app) | Mounting Tiler in an existing Rails 7+ application — Gemfile, initializer, routes, custom-widget hook |
| [`json-ingest/`](./examples/json-ingest) | Sending data into Tiler from any system that speaks HTTP+JSON — curl, Node, Python, Bash |
| [`selenium-ruby-rspec/`](./examples/selenium-ruby-rspec) | E2E testing Tiler dashboards from a Ruby/RSpec suite |
| [`cypress/`](./examples/cypress) | E2E testing Tiler dashboards from Cypress |
| [`playwright/`](./examples/playwright) | E2E testing Tiler dashboards from Playwright |

For a full testability analysis (stable selector inventory + per-framework scoring), see [`context/refs/tiler-e2e-testability.md`](./context/refs/tiler-e2e-testability.md).

## License

MIT.
