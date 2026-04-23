# Tiler E2E — Selenium + Ruby + RSpec

Minimal RSpec suite driving a running Tiler dashboard via Selenium WebDriver.

## Setup

```bash
cd examples/selenium-ruby-rspec
bundle install
```

Requires Chrome installed. The suite uses `webdriver-manager` style auto-download via Selenium 4.

## Run

Point `TILER_BASE_URL` at your dashboard host. Defaults to `http://127.0.0.1:3131` (the Tiler dummy app).

```bash
TILER_BASE_URL=http://127.0.0.1:3131 \
TILER_DASHBOARD_SLUG=demo \
bundle exec rspec
```

## Files

- `Gemfile` — selenium-webdriver, rspec, rspec-html-matchers
- `spec/spec_helper.rb` — driver setup (headless Chrome by default; set `HEADED=1` to see the browser)
- `spec/dashboard_spec.rb` — three example tests
