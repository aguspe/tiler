module Tiler
  module Presets
    # Default preset — a generic "hello world" dashboard touching every
    # widget in the registry. Mirrors the legacy `bin/rails tiler:seed` task
    # so existing demos keep working.
    class Default < Base
      def slug;        "demo"; end
      def name;        "Demo Dashboard"; end
      def description; "Seeded by Tiler — every built-in widget on one grid."; end

      def data_sources!
        {
          requests: upsert_source(
            slug: "demo_requests", name: "Demo Requests",
            description: "Sample request log — feeds the metric/chart/table panels.",
            schema: [
              { "key" => "status",   "type" => "string" },
              { "key" => "duration", "type" => "float"  }
            ]
          ),
          quotes: upsert_source(
            slug: "demo_quotes", name: "Demo Quotes",
            description: "Sample quotes for the comments widget.",
            schema: [
              { "key" => "quote",  "type" => "string" },
              { "key" => "author", "type" => "string" },
              { "key" => "avatar", "type" => "string" }
            ],
            ingestion: %w[manual]
          )
        }
      end

      def panels!(dash, sources)
        s = sources[:requests]
        q = sources[:quotes]

        add_panel(dash, title: "Clock", widget_type: "clock",
                  x: 0, y: 0, width: 3, height: 2)
        add_panel(dash, title: "Requests (24h)", widget_type: "metric",
                  x: 3, y: 0, width: 3, height: 2, data_source: s,
                  config: { aggregation: "count", time_window: "24h" })
        add_panel(dash, title: "Status today", widget_type: "number_with_delta",
                  x: 6, y: 0, width: 3, height: 2, data_source: s,
                  config: { value_column: "duration", aggregation: "avg",
                            time_window: "24h", delta_window: "24h" })
        add_panel(dash, title: "About", widget_type: "text",
                  x: 9, y: 0, width: 3, height: 2,
                  config: { body: "Tiler default preset — drag panels to rearrange." })
        add_panel(dash, title: "Avg duration (7d)", widget_type: "line_chart",
                  x: 0, y: 2, width: 8, height: 3, data_source: s,
                  config: { time_window: "7d", bucket: "1d",
                            series: [ { label: "duration", column: "duration", agg: "avg" } ] })
        add_panel(dash, title: "Breakdown by status", widget_type: "pie_chart",
                  x: 8, y: 2, width: 4, height: 3, data_source: s,
                  config: { group_column: "status", aggregation: "count", time_window: "7d" })
        add_panel(dash, title: "Top statuses", widget_type: "list",
                  x: 0, y: 5, width: 4, height: 3, data_source: s,
                  config: { label_column: "status", aggregation: "count",
                            time_window: "7d", limit: 10, order: "desc" })
        add_panel(dash, title: "Avg duration meter", widget_type: "meter",
                  x: 4, y: 5, width: 4, height: 3, data_source: s,
                  config: { value_column: "duration", aggregation: "avg",
                            time_window: "24h", min: 0, max: 1000, suffix: " ms" })
        add_panel(dash, title: "Recent comments", widget_type: "comments",
                  x: 8, y: 5, width: 4, height: 3, data_source: q,
                  config: { quote_column: "quote", name_column: "author",
                            avatar_column: "avatar", time_window: "7d",
                            limit: 10, rotate_seconds: 5 })
      end

      def sample_records!(sources)
        seed!(sources[:requests], 60.times.map {
          { status: %w[ok ok ok error].sample, duration: rand(5.0..900.0).round(2) }
        })
        seed!(sources[:quotes], [
          { quote: "Make it work, make it right, make it fast.",  author: "Kent Beck",        avatar: "https://i.pravatar.cc/64?u=kent"  },
          { quote: "Premature optimization is the root of all evil.", author: "Donald Knuth", avatar: "https://i.pravatar.cc/64?u=knuth" },
          { quote: "Simplicity is the ultimate sophistication.",  author: "Leonardo da Vinci", avatar: "https://i.pravatar.cc/64?u=leo"  },
          { quote: "First, solve the problem. Then, write the code.", author: "John Johnson", avatar: "https://i.pravatar.cc/64?u=john" },
          { quote: "Code is like humor. When you have to explain it, it's bad.", author: "Cory House", avatar: "https://i.pravatar.cc/64?u=cory" }
        ])
      end
    end

    register :default, Default
  end
end
