namespace :tiler do
  desc "Seed example dashboard + data source + records into the host app"
  task seed: :environment do
    source = Tiler::DataSource.find_or_create_by!(slug: "demo_requests") do |s|
      s.name              = "Demo Requests"
      s.description       = "Sample data source seeded by Tiler."
      s.active            = true
      s.schema_definition = [
        { "key" => "status",   "type" => "string" },
        { "key" => "duration", "type" => "float"  }
      ].to_json
      s.ingestion_methods = [ "webhook", "manual" ].to_json
    end

    dash = Tiler::Dashboard.find_or_create_by!(slug: "demo") do |d|
      d.name            = "Demo Dashboard"
      d.description     = "Seeded by Tiler."
      d.refresh_seconds = 60
    end

    if dash.panels.empty?
      dash.panels.create!(title: "Clock", widget_type: "clock",
                          x: 0, y: 0, width: 3, height: 2,
                          config: {}.to_json)
      dash.panels.create!(title: "Requests (24h)", widget_type: "metric",
                          x: 3, y: 0, width: 3, height: 2, data_source: source,
                          config: { aggregation: "count", time_window: "24h" }.to_json)
      dash.panels.create!(title: "Status today", widget_type: "number_with_delta",
                          x: 6, y: 0, width: 3, height: 2, data_source: source,
                          config: { value_column: "duration", aggregation: "avg",
                                    time_window: "24h", previous_window: "24h" }.to_json)
      dash.panels.create!(title: "About", widget_type: "text",
                          x: 9, y: 0, width: 3, height: 2,
                          config: { text: "Tiler demo dashboard — drag panels to rearrange." }.to_json)
      dash.panels.create!(title: "Avg duration (7d)", widget_type: "line_chart",
                          x: 0, y: 2, width: 8, height: 3, data_source: source,
                          config: { value_column: "duration", aggregation: "avg",
                                    bucket: "day", time_window: "7d" }.to_json)
      dash.panels.create!(title: "Breakdown by status", widget_type: "pie_chart",
                          x: 8, y: 2, width: 4, height: 3, data_source: source,
                          config: { group_by: "status", aggregation: "count",
                                    time_window: "7d" }.to_json)
      dash.panels.create!(title: "Top statuses", widget_type: "list",
                          x: 0, y: 5, width: 4, height: 3, data_source: source,
                          config: { group_by: "status", aggregation: "count",
                                    time_window: "7d", limit: 10 }.to_json)
      dash.panels.create!(title: "Docs", widget_type: "iframe",
                          x: 4, y: 5, width: 8, height: 3,
                          config: { url: "https://smashing.github.io/" }.to_json)
      dash.panels.create!(title: "Logo", widget_type: "image",
                          x: 0, y: 8, width: 4, height: 3,
                          config: { url: "https://smashing.github.io/img/logo.png",
                                    alt: "Smashing logo", fit: "contain" }.to_json)
      dash.panels.create!(title: "Avg duration meter", widget_type: "meter",
                          x: 4, y: 8, width: 4, height: 3, data_source: source,
                          config: { value_column: "duration", aggregation: "avg",
                                    time_window: "24h", min: 0, max: 1000,
                                    suffix: " ms" }.to_json)
      dash.panels.create!(title: "Recent comments", widget_type: "comments",
                          x: 8, y: 8, width: 4, height: 3, data_source: source,
                          config: { quote_column: "status", time_window: "7d",
                                    limit: 10, rotate_seconds: 5 }.to_json)
    end

    if source.data_records.count < 50
      60.times do
        source.data_records.create!(
          payload:      { status: %w[ok ok ok error].sample, duration: rand(5.0..900.0).round(2) }.to_json,
          recorded_at:  rand(7.days).seconds.ago,
          ingested_via: "manual"
        )
      end
    end

    puts "Tiler seeded. Visit /tiler/dashboards/#{dash.slug}"
  end
end
