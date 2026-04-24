module Tiler
  module Presets
    # Test-automation preset — a CI/QA cockpit. Single data source streams
    # one record per test execution. Layout focuses on the four numbers
    # most teams actually care about (pass rate, total runs, failures,
    # avg duration), then breaks down by suite and time.
    #
    # Push records as:
    #   POST /tiler/ingest/test_runs
    #   { "suite": "checkout", "test_name": "places order",
    #     "status": "pass|fail|warn|skip", "duration_ms": 142,
    #     "environment": "ci" }
    class TestAutomation < Base
      def slug;        "test_automation"; end
      def name;        "Test Automation"; end
      def description; "QA cockpit — pass rate, suite breakdown, recent runs."; end

      def data_sources!
        {
          runs: upsert_source(
            slug: "test_runs", name: "Test Runs",
            description: "One record per test execution.",
            schema: [
              { "key" => "suite",       "type" => "string"  },
              { "key" => "test_name",   "type" => "string"  },
              { "key" => "status",      "type" => "string"  },
              { "key" => "duration_ms", "type" => "float"   },
              { "key" => "environment", "type" => "string"  }
            ]
          )
        }
      end

      def panels!(dash, sources)
        s = sources[:runs]

        add_panel(dash, title: "Total runs (24h)", widget_type: "metric",
                  x: 0, y: 0, width: 3, height: 2, data_source: s,
                  config: { aggregation: "count", time_window: "24h" })
        add_panel(dash, title: "Failures (24h)", widget_type: "number_with_delta",
                  x: 3, y: 0, width: 3, height: 2, data_source: s,
                  config: { value_column: "duration_ms", aggregation: "count",
                            time_window: "24h", delta_window: "24h",
                            filter: { status: "fail" }, color: "#ef4444" })
        add_panel(dash, title: "Avg duration (ms)", widget_type: "metric",
                  x: 6, y: 0, width: 3, height: 2, data_source: s,
                  config: { value_column: "duration_ms", aggregation: "avg",
                            time_window: "24h", suffix: " ms" })
        add_panel(dash, title: "Build clock", widget_type: "clock",
                  x: 9, y: 0, width: 3, height: 2)

        add_panel(dash, title: "Status breakdown (24h)", widget_type: "pie_chart",
                  x: 0, y: 2, width: 6, height: 3, data_source: s,
                  config: { group_column: "status", aggregation: "count",
                            time_window: "24h",
                            palette: [ "#10b981", "#f59e0b", "#ef4444", "#6b7280" ] })
        add_panel(dash, title: "Avg duration trend (7d)", widget_type: "line_chart",
                  x: 6, y: 2, width: 6, height: 3, data_source: s,
                  config: { time_window: "7d", bucket: "1d",
                            series: [
                              { label: "duration", column: "duration_ms", agg: "avg", color: "#3b82f6" }
                            ] })

        add_panel(dash, title: "Suites by status", widget_type: "status_grid",
                  x: 0, y: 5, width: 8, height: 3, data_source: s,
                  config: { group_column: "suite", status_column: "status",
                            time_window: "24h" })
        add_panel(dash, title: "Top failing tests (24h)", widget_type: "list",
                  x: 8, y: 5, width: 4, height: 3, data_source: s,
                  config: { label_column: "test_name", aggregation: "count",
                            time_window: "24h", limit: 10, order: "desc",
                            filter: { status: "fail" } })

        add_panel(dash, title: "Failures by suite", widget_type: "bar_chart",
                  x: 0, y: 8, width: 8, height: 3, data_source: s,
                  config: { group_column: "suite", value_column: "duration_ms",
                            aggregation: "count", time_window: "24h",
                            filter: { status: "fail" } })
        add_panel(dash, title: "How to push test results", widget_type: "text",
                  x: 8, y: 8, width: 4, height: 3,
                  config: { body: <<~MD })
                    Push results to /tiler/ingest/test_runs.

                    Required fields:
                    - suite
                    - test_name
                    - status (pass / fail / warn / skip)
                    - duration_ms

                    Wire your CI to fire one POST per assertion.
                  MD
      end

      def sample_records!(sources)
        runs = sources[:runs]
        suites    = %w[checkout payments search auth catalog reporting]
        statuses  = %w[pass pass pass pass pass warn fail skip]
        seed!(runs, 200.times.map {
          {
            suite:       suites.sample,
            test_name:   "case_#{rand(1..40)}",
            status:      statuses.sample,
            duration_ms: rand(20..2_500),
            environment: %w[ci staging local].sample
          }
        })
      end
    end

    register :test_automation, TestAutomation
  end
end
