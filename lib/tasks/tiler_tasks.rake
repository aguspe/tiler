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

    quotes_source = Tiler::DataSource.find_or_create_by!(slug: "demo_quotes") do |s|
      s.name              = "Demo Quotes"
      s.description       = "Sample quotes for the comments widget."
      s.active            = true
      s.schema_definition = [
        { "key" => "quote",  "type" => "string" },
        { "key" => "author", "type" => "string" },
        { "key" => "avatar", "type" => "string" }
      ].to_json
      s.ingestion_methods = [ "manual" ].to_json
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
                          x: 8, y: 8, width: 4, height: 3, data_source: quotes_source,
                          config: { quote_column: "quote", name_column: "author",
                                    avatar_column: "avatar", time_window: "7d",
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

    if quotes_source.data_records.empty?
      [
        { quote: "Make it work, make it right, make it fast.",  author: "Kent Beck",        avatar: "https://i.pravatar.cc/64?u=kent"  },
        { quote: "Premature optimization is the root of all evil.", author: "Donald Knuth", avatar: "https://i.pravatar.cc/64?u=knuth" },
        { quote: "Simplicity is the ultimate sophistication.",  author: "Leonardo da Vinci", avatar: "https://i.pravatar.cc/64?u=leo"  },
        { quote: "First, solve the problem. Then, write the code.", author: "John Johnson", avatar: "https://i.pravatar.cc/64?u=john" },
        { quote: "Code is like humor. When you have to explain it, it's bad.", author: "Cory House", avatar: "https://i.pravatar.cc/64?u=cory" }
      ].each_with_index do |q, i|
        quotes_source.data_records.create!(
          payload:      q.to_json,
          recorded_at:  (i + 1).hours.ago,
          ingested_via: "manual"
        )
      end
    end

    puts "Tiler seeded. Visit /tiler/dashboards/#{dash.slug}"
  end
end
