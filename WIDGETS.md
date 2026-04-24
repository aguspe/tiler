# Widgets — extension contract

Tiler ships fourteen built-in widgets, but the registry is open. Drop a Ruby
class in `app/widgets/`, define a partial, and Tiler picks it up on boot.
Widgets can also be defined at runtime through Settings (Liquid template, no
code) or distributed as standalone Ruby gems.

## Quickstart (Ruby, host app)

```bash
bin/rails generate tiler:widget weather
```

Creates:

- `app/widgets/tiler/weather_widget.rb` — the Widget + optional Query class
- `app/views/tiler/widgets/_weather.html.erb` — the partial

The generated file ends with `Tiler.widgets.register("weather", klass: …)`. The
engine eager-loads everything under `app/widgets/**` on boot and re-loads on
dev change, so you don't touch any initializer.

Open Settings → Add Panel → **Weather** to drop a tile in.

## The contract

A widget is a subclass of `Tiler::Widget` with the following surface.

### Required

```ruby
module Tiler
  class WeatherWidget < ::Tiler::Widget
    self.type    = "weather"             # registry key, used in panel.widget_type
    self.partial = "tiler/widgets/weather"
    self.label   = "Weather"             # shown in the widget palette
  end
end

Tiler.widgets.register("weather", klass: Tiler::WeatherWidget)
```

### Sizing (defaults if omitted)

| Attribute       | Default      | Meaning                                 |
| --------------- | ------------ | --------------------------------------- |
| `default_size`  | `{w:6,h:2}`  | initial cells the tile occupies         |
| `min_size`      | `{w:1,h:1}`  | resize floor enforced by gridstack      |
| `max_size`      | `{w:12,h:12}`| resize ceiling                          |

### Data — query class

If your widget reads from a `Tiler::DataSource`, define a `Query::Base`
subclass:

```ruby
class WeatherQuery < ::Tiler::Query::Base
  def call
    # Returns the hash the partial reads as `data`.
    {
      city: config["city"],
      temp: aggregate(base_scope, "temp_f", "last")
    }
  end
end
```

Helpers exposed on `Query::Base`:

| Helper                       | Returns                                                  |
| ---------------------------- | -------------------------------------------------------- |
| `base_scope`                 | filtered, time-windowed `DataRecord` scope              |
| `apply_filters(scope)`       | scope with `config["filter"]` applied                    |
| `aggregate(scope, col, agg)` | sum/avg/min/max/count/last on a payload column          |
| `distinct_values(col)`       | unique payload values for `col`                          |
| `safe_col?(col)`             | `true` when col is `[A-Za-z0-9_]+`                       |
| `chart_colors`               | palette honoring per-panel `color`/`palette` overrides   |
| `time_window_start`          | start `Time` for the active `time_window` config         |

Wire the query class with `self.query_class = WeatherQuery`.

### Data — config-only widgets

Set `self.query_class = nil` and override `data`:

```ruby
def data
  { city: config["city"] }
end
```

### Partial

The partial receives two locals — `panel` (the AR record) and `data` (the hash
your query returned). Wrap content in a single root element with a
`tiler-<type>` class hook so the design system can target it.

```erb
<div class="tiler-weather">
  <div class="tiler-weather-city"><%= data[:city] %></div>
  <div class="tiler-weather-temp"><%= data[:temp] %>°F</div>
</div>
```

### Optional hooks

| Hook                          | Purpose                                                              |
| ----------------------------- | -------------------------------------------------------------------- |
| `default_config`              | Hash pre-populated when a panel is created                           |
| `empty?(data)`                | When `true`, the panel renders the global "Configure" empty state    |
| `self.example_config`         | JSON shown on the edit form so users can copy-paste a starting point |
| `self.example_payload`        | Sample webhook record shown next to the curl one-liner               |
| `self.example_preview`        | Static `_preview` JSON pasted into Config to render without a source |
| `self.supports_color_config?` | `true` exposes the per-panel single-color picker on the edit form    |
| `self.supports_palette_config?` | `true` adds the comma-separated palette input                       |

Color/palette override is read automatically by `chart_colors` — opt your
widget in if it renders a colored visualization.

### Empty state rule

The default `empty?` returns true when the widget is data-backed
(`query_class` set) AND the panel has no data source AND no `_preview` config.
Subclasses override for stricter checks (e.g. chart widgets also check that
every dataset isn't all zeros).

## Testing your widget

Add `Tiler::WidgetTestHelper` to your test class for shared assertions:

```ruby
class WeatherWidgetTest < ActiveSupport::TestCase
  include Tiler::WidgetTestHelper

  test "renders without raising at the default size" do
    assert_widget_renders("weather", config: { city: "Berlin" })
  end

  test "data hash includes city and temp" do
    data = widget_data("weather", config: { city: "Berlin" })
    assert_equal "Berlin", data[:city]
  end
end
```

The mixin also exposes `assert_widget_in_registry("weather")`,
`assert_widget_default_size("weather", w: 6, h: 2)`, and others — see
`lib/tiler/test_helpers.rb` for the full surface.

## Catalog parity

The engine ships `test/lib/tiler/widgets/catalog_parity_test.rb` which fails
CI if any built-in widget drifts from the design catalog. Host apps with
custom widgets can add their own parity check by extending the same pattern
under `test/widgets/your_catalog_test.rb`.

## Packaging widgets as gems

The cleanest distribution path for a community widget is its own gem.

1. `bundle gem tiler-weather`
2. In the gem's lib, require + register inside a Railtie initializer:

   ```ruby
   class Tiler::Weather::Railtie < ::Rails::Railtie
     initializer "tiler-weather.register" do
       require "tiler/weather/widget"
       # auto-registers via the Tiler.widgets.register call inside that file
     end
   end
   ```

3. Add `app/views/tiler/widgets/_weather.html.erb` inside the gem so the
   partial path resolves once the gem is added to the host app's Gemfile.
4. Depend on `tiler` (`~> 0.x`) in the gemspec.

Host apps install: `bundle add tiler-weather` — no further wiring.

## Runtime, no-code widgets

Settings → **Custom widgets** lets non-engineers define a widget through a
Liquid template + a small JSON describing the data query. See "User-defined
widgets" in the README for the security model and the limits on the data
query language. Runtime widgets register through the same global registry
the Ruby ones use, so everything else (drag-drop, theme, color override,
edit drawer) just works.
