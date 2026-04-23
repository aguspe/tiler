# Tiler

Plug-and-play dashboards for Rails. Configurable widgets, JSON data sources, webhook ingestion, Turbo-powered live panels. Inspired by [Smashing](https://github.com/Smashing/smashing).

## Features

- 📊 **6 built-in widgets**: metric, table, line chart, bar chart, pie chart, status grid
- 🔌 **Widget registry**: plug in your own widgets from the host app
- 🗄️ **Schemaless data sources**: JSON payloads, schema is descriptive not enforced
- 📥 **Multi-channel ingestion**: webhook (HMAC-style token), manual entry, CSV import
- ⚡ **Turbo Frames**: lazy-loaded panels, optional auto-refresh
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

## Register a custom widget

```ruby
# config/initializers/tiler.rb
Tiler.register_widget(:sparkline,
  label:   "Sparkline",
  partial: "my_app/widgets/sparkline",
  query:   MyApp::Widgets::SparklineQuery)
```

A query class subclasses `Tiler::Query::Base` and returns a hash consumed by the partial:

```ruby
class MyApp::Widgets::SparklineQuery < Tiler::Query::Base
  def call
    { points: base_scope.pluck(:recorded_at, Arel.sql(json_extract("value"))) }
  end
end
```

The partial renders with `panel:` and `data:` locals:

```erb
<!-- app/views/my_app/widgets/_sparkline.html.erb -->
<svg>...</svg>
```

## Ingest data via webhook

Every data source with `webhook` enabled gets a token shown on its detail page:

```bash
curl -X POST https://your-app.com/tiler/ingest/my_source \
  -H "X-Tiler-Token: <token>" \
  -H "Content-Type: application/json" \
  -d '{"status":"ok","duration":142.3}'
```

Send a JSON object (one record) or a JSON array (batch).

## Model overview

- `Tiler::Dashboard` — `has_many :panels`
- `Tiler::Panel` — `widget_type`, `col_span`, `config` (JSON), `belongs_to :data_source`
- `Tiler::DataSource` — `schema_definition`, `ingestion_methods`, `webhook_token`
- `Tiler::DataRecord` — `payload` (JSON), `recorded_at`, `ingested_via`

All four are scoped under the `tiler_` table prefix to avoid colliding with host models.

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
