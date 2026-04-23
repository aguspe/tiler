# Tiler in a Rails Host App

How to mount the Tiler engine inside an existing Rails 7+ application.

## 1. Add the gem

In your host app's `Gemfile`:

```ruby
gem "tiler", github: "aguspe/tiler"   # or path: "../tiler" during development
```

Then:

```bash
bundle install
```

## 2. Run the install generator

```bash
bin/rails generate tiler:install
bin/rails db:migrate
```

The generator copies migrations into your host app's `db/migrate/` and writes `config/initializers/tiler.rb` with sensible defaults.

## 3. Mount the engine

In your host app's `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  # ... your routes ...
  mount Tiler::Engine => "/tiler"
end
```

You can mount it under any path. Common choices: `/dashboards`, `/admin/dashboards`, `/internal/tiler`.

## 4. Configure (optional)

Edit `config/initializers/tiler.rb`:

```ruby
Tiler.configure do |config|
  # Inherit from your auth-aware controller
  config.parent_controller = "::ApplicationController"

  # Lambdas decide who can view / manage dashboards. Have access to the controller via `ctrl`.
  config.authorize_view    = ->(ctrl) { ctrl.send(:user_signed_in?) }
  config.authorize_manage  = ->(ctrl) { ctrl.send(:current_user)&.admin? }

  # Default refresh cadence for dashboards (seconds)
  config.default_refresh_seconds = 60

  # Eager-load panel turbo-frames in tests so system specs don't race lazy intersection-observer
  config.eager_panel_load = Rails.env.test?
end
```

The two `authorize_*` lambdas are the integration point with whatever auth system you use (Devise, Clearance, custom). They run in the controller context, so any helper your `ApplicationController` defines is callable.

## 5. (Optional) Register a custom widget

In `config/initializers/tiler.rb`, after `Tiler.configure`:

```ruby
Tiler.register_widget(:sparkline,
  label:   "Sparkline",
  partial: "my_app/widgets/sparkline",
  query:   MyApp::Widgets::SparklineQuery)
```

A query class is a `Tiler::Query::Base` subclass returning a hash:

```ruby
# app/queries/my_app/widgets/sparkline_query.rb
class MyApp::Widgets::SparklineQuery < Tiler::Query::Base
  def call
    { points: base_scope.pluck(:recorded_at, Arel.sql(json_extract("value"))) }
  end
end
```

The partial renders with `panel:` and `data:` locals:

```erb
<!-- app/views/my_app/widgets/_sparkline.html.erb -->
<svg class="sparkline" data-points="<%= data[:points].to_json %>"></svg>
```

## 6. (Optional) Seed a dashboard from your host

```ruby
# db/seeds.rb (or a rake task)
source = Tiler::DataSource.find_or_create_by!(slug: "checkout_metrics") do |s|
  s.name              = "Checkout Metrics"
  s.schema_definition = [
    { "key" => "status",   "type" => "string" },
    { "key" => "duration", "type" => "float"  }
  ].to_json
  s.ingestion_methods = ["webhook", "manual"].to_json
end

dashboard = Tiler::Dashboard.find_or_create_by!(slug: "checkout") do |d|
  d.name = "Checkout"
  d.refresh_seconds = 30
end

dashboard.panels.find_or_create_by!(title: "Avg duration") do |p|
  p.widget_type = "metric"
  p.data_source = source
  p.x = 0; p.y = 0; p.width = 4; p.height = 2
  p.config = { aggregation: "avg", value_column: "duration", time_window: "24h" }.to_json
end
```

Run `bin/rails db:seed` and visit `/tiler/dashboards/checkout`.

## 7. Visit your dashboard

Boot your host app and open `http://localhost:3000/tiler` (or whatever path you mounted at). The dashboards index appears; click any dashboard to view its panels.

## Files in this example

- `Gemfile.snippet` — copy-paste lines to add to your host's Gemfile
- `config/initializers/tiler.rb` — the initializer that the install generator writes (with comments)
- `config/routes.rb.snippet` — the one-line mount

## See also

- [`../json-ingest/`](../json-ingest) — push data into Tiler from any system that can speak JSON
- [`../selenium-ruby-rspec/`](../selenium-ruby-rspec), [`../cypress/`](../cypress), [`../playwright/`](../playwright) — e2e testing your dashboards
