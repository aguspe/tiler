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
      dash.panels.create!(title: "Requests (24h)", widget_type: "metric",
                          col_span: 1, position: 0, data_source: source,
                          config: { aggregation: "count", time_window: "24h" }.to_json)
      dash.panels.create!(title: "Avg duration (7d)", widget_type: "line_chart",
                          col_span: 2, position: 1, data_source: source,
                          config: { value_column: "duration", aggregation: "avg",
                                    bucket: "day", time_window: "7d" }.to_json)
      dash.panels.create!(title: "Breakdown by status", widget_type: "pie_chart",
                          col_span: 1, position: 2, data_source: source,
                          config: { group_by: "status", aggregation: "count",
                                    time_window: "7d" }.to_json)
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
