module Tiler
  module Presets
    # Commerce preset — operations dashboard for an online shop. One source
    # for orders, one for sessions (so conversion can be computed). Headline
    # KPIs up top, trend + breakdowns below.
    #
    # Push records as:
    #   POST /tiler/ingest/orders
    #   { "order_id": "ORD-001", "customer": "alice",
    #     "total": 129.5, "status": "paid", "items_count": 3,
    #     "channel": "web", "product": "Wireless Headphones" }
    #
    #   POST /tiler/ingest/sessions
    #   { "session_id": "S-001", "channel": "web", "converted": false }
    class Commerce < Base
      def slug;        "commerce"; end
      def name;        "Commerce Shop"; end
      def description; "Live operations — revenue, orders, AOV, conversion."; end

      def data_sources!
        {
          orders: upsert_source(
            slug: "orders", name: "Orders",
            description: "One record per order — drives revenue + AOV + status panels.",
            schema: [
              { "key" => "order_id",    "type" => "string" },
              { "key" => "customer",    "type" => "string" },
              { "key" => "total",       "type" => "float"  },
              { "key" => "status",      "type" => "string" },
              { "key" => "items_count", "type" => "integer" },
              { "key" => "channel",     "type" => "string" },
              { "key" => "product",     "type" => "string" }
            ]
          ),
          sessions: upsert_source(
            slug: "sessions", name: "Sessions",
            description: "One record per browsing session — used for conversion rate.",
            schema: [
              { "key" => "session_id", "type" => "string"  },
              { "key" => "channel",    "type" => "string"  },
              { "key" => "converted",  "type" => "boolean" }
            ]
          )
        }
      end

      def panels!(dash, sources)
        o = sources[:orders]

        add_panel(dash, title: "Revenue today", widget_type: "metric",
                  x: 0, y: 0, width: 3, height: 2, data_source: o,
                  config: { value_column: "total", aggregation: "sum",
                            time_window: "24h", prefix: "$" })
        add_panel(dash, title: "Orders today", widget_type: "number_with_delta",
                  x: 3, y: 0, width: 3, height: 2, data_source: o,
                  config: { value_column: "total", aggregation: "count",
                            time_window: "24h", delta_window: "24h",
                            color: "#10b981" })
        add_panel(dash, title: "Avg order value", widget_type: "metric",
                  x: 6, y: 0, width: 3, height: 2, data_source: o,
                  config: { value_column: "total", aggregation: "avg",
                            time_window: "24h", prefix: "$" })
        add_panel(dash, title: "Items per order", widget_type: "meter",
                  x: 9, y: 0, width: 3, height: 2, data_source: o,
                  config: { value_column: "items_count", aggregation: "avg",
                            time_window: "24h", min: 0, max: 10, suffix: " items" })

        add_panel(dash, title: "Revenue trend (30d)", widget_type: "line_chart",
                  x: 0, y: 2, width: 8, height: 3, data_source: o,
                  config: { time_window: "30d", bucket: "1d",
                            series: [
                              { label: "Revenue", column: "total", agg: "sum", color: "#3b82f6" }
                            ] })
        add_panel(dash, title: "Orders by status", widget_type: "pie_chart",
                  x: 8, y: 2, width: 4, height: 3, data_source: o,
                  config: { group_column: "status", aggregation: "count",
                            time_window: "30d",
                            palette: [ "#10b981", "#f59e0b", "#3b82f6", "#ef4444", "#6b7280" ] })

        add_panel(dash, title: "Top products by revenue", widget_type: "list",
                  x: 0, y: 5, width: 4, height: 3, data_source: o,
                  config: { label_column: "product", value_column: "total",
                            aggregation: "sum", time_window: "30d",
                            limit: 10, order: "desc" })
        add_panel(dash, title: "Channel performance", widget_type: "bar_chart",
                  x: 4, y: 5, width: 4, height: 3, data_source: o,
                  config: { group_column: "channel", value_column: "total",
                            aggregation: "sum", time_window: "30d", limit: 10 })
        add_panel(dash, title: "Recent orders", widget_type: "table",
                  x: 8, y: 5, width: 4, height: 3, data_source: o,
                  config: {
                    group_by: "order_id", time_window: "24h", limit: 10,
                    columns: [
                      { label: "Total",  column: "total",       num: true,  agg: "last" },
                      { label: "Items",  column: "items_count", num: true,  agg: "last" },
                      { label: "Status", column: "status",      num: false, agg: "last" }
                    ]
                  })

        add_panel(dash, title: "Shop time", widget_type: "clock",
                  x: 0, y: 8, width: 3, height: 2)
        add_panel(dash, title: "How to push orders", widget_type: "text",
                  x: 3, y: 8, width: 9, height: 2,
                  config: { body: <<~MD })
                    Push order events to /tiler/ingest/orders.

                    Required fields: order_id, customer, total, status, items_count, channel, product.
                    Wire your checkout pipeline to fire one POST per order created / status change.
                  MD
      end

      def sample_records!(sources)
        orders   = sources[:orders]
        sessions = sources[:sessions]
        products = [ "Wireless Headphones", "Smartwatch", "Bluetooth Speaker",
                     "Laptop Stand", "Mechanical Keyboard", "USB-C Hub", "4K Monitor" ]
        channels = %w[web mobile ios android]
        statuses = %w[paid paid paid pending refunded cancelled]

        seed!(orders, 200.times.map { |i|
          {
            order_id:    "ORD-#{1000 + i}",
            customer:    "user_#{rand(1..120)}",
            total:       rand(15.0..480.0).round(2),
            status:      statuses.sample,
            items_count: rand(1..6),
            channel:     channels.sample,
            product:     products.sample
          }
        }, spread: 30.days)

        seed!(sessions, 800.times.map { |i|
          {
            session_id: "SES-#{2000 + i}",
            channel:    channels.sample,
            converted:  [ true, false, false, false, false, false ].sample
          }
        }, spread: 30.days)
      end
    end

    register :commerce, Commerce
  end
end
