# Tiler + Selenium (Ruby + RSpec)

A starter for driving a Tiler dashboard from a Selenium-WebDriver suite in
your own app. The three example tests show the patterns you'll re-use; copy
them into your suite, then write whatever assertions your dashboard cares
about.

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

## 2. Install Selenium + RSpec

```bash
cd examples/selenium-ruby-rspec
bundle install
```

Requires Chrome installed locally — Selenium 4 auto-downloads the matching
ChromeDriver.

## 3. Run

Point `TILER_BASE_URL` at the host running Tiler. `TILER_DASHBOARD_SLUG`
defaults to `demo` (matches `bin/rails tiler:seed`).

```bash
TILER_BASE_URL=http://127.0.0.1:3000 \
TILER_DASHBOARD_SLUG=demo \
bundle exec rspec
```

Watch the browser instead of headless:

```bash
HEADED=1 bundle exec rspec
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

- `Gemfile` — selenium-webdriver, rspec
- `spec/spec_helper.rb` — driver setup (headless Chrome by default; `HEADED=1` to see the browser)
- `spec/dashboard_spec.rb` — three example tests
