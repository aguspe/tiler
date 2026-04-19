# Changelog

## 0.1.0 — 2026-04-19

Initial release.

- Mountable Rails engine with Dashboard / Panel / DataSource / DataRecord models
- 6 built-in widgets: metric, table, line_chart, bar_chart, pie_chart, status_grid
- Widget registry for adding custom widgets from host apps
- Webhook ingestion endpoint with per-source token auth
- Install generator (`rails g tiler:install`)
- Seed task (`rails tiler:seed`)
- Configurable authorization via lambdas
