require "test_helper"

module Tiler
  module Widgets
    class CommentsTest < ActionView::TestCase
      setup do
        @source = create_data_source
        @dash   = create_dashboard
        # Three records with all three keys present, one with missing name and avatar.
        create_record(@source, { quote: "First", author: "Alice", pic: "https://example.com/a.png" },
                      recorded_at: 3.hours.ago)
        create_record(@source, { quote: "Second", author: "Bob", pic: "https://example.com/b.png" },
                      recorded_at: 2.hours.ago)
        create_record(@source, { quote: "Third (no name)", pic: "https://example.com/c.png" },
                      recorded_at: 1.hour.ago)
        create_record(@source, { quote: "Fourth (no avatar)", author: "Dee" },
                      recorded_at: 30.minutes.ago)
      end

      def panel_with(config = {})
        create_panel(@dash, widget_type: "comments", data_source: @source, config: config.to_json)
      end

      def render_partial(panel)
        render partial: "tiler/widgets/comments", locals: { panel: panel, data: panel.data }
      end

      test "registry returns the registered class with documented attributes" do
        klass = Tiler.widgets["comments"]
        assert_equal Tiler::Widgets::Comments, klass
        assert_equal "comments", klass.type
        assert_equal "Comments", klass.label
        assert_equal "tiler/widgets/comments", klass.partial
        assert_equal Tiler::Widgets::CommentsQuery, klass.query_class
      end

      test "query returns hash with items and rotate_seconds keys" do
        data = panel_with(quote_column: "quote", name_column: "author",
                          avatar_column: "pic").data
        assert data.key?(:items)
        assert data.key?(:rotate_seconds)
      end

      test "items array entries have exactly quote, name, avatar keys" do
        data = panel_with(quote_column: "quote", name_column: "author",
                          avatar_column: "pic").data
        data[:items].each do |item|
          assert_equal %i[quote name avatar].sort, item.keys.sort
        end
      end

      test "items are ordered by recorded_at DESC" do
        data = panel_with(quote_column: "quote", name_column: "author",
                          avatar_column: "pic").data
        quotes = data[:items].map { |i| i[:quote] }
        # Most recent first: "Fourth (no avatar)", "Third (no name)", "Second", "First"
        assert_equal "Fourth (no avatar)", quotes.first
        assert_equal "First", quotes.last
      end

      test "items length is at most config limit (default 10)" do
        data = panel_with(quote_column: "quote").data
        assert_operator data[:items].size, :<=, 10
      end

      test "limit clamped to upper bound (100)" do
        data = panel_with(quote_column: "quote", limit: 9999).data
        assert_operator data[:items].size, :<=, 100
      end

      test "missing name_column config yields nil :name" do
        data = panel_with(quote_column: "quote", avatar_column: "pic").data
        assert(data[:items].all? { |i| i[:name].nil? })
      end

      test "missing avatar_column config yields nil :avatar" do
        data = panel_with(quote_column: "quote", name_column: "author").data
        assert(data[:items].all? { |i| i[:avatar].nil? })
      end

      test "missing payload key yields nil for that field, no raise" do
        data = panel_with(quote_column: "quote", name_column: "author",
                          avatar_column: "pic").data
        # "Third (no name)" has no author key in payload; "Fourth" has no pic.
        third = data[:items].find { |i| i[:quote] == "Third (no name)" }
        fourth = data[:items].find { |i| i[:quote] == "Fourth (no avatar)" }
        assert_nil third[:name]
        assert_nil fourth[:avatar]
      end

      test "empty data source yields items: [] and a rotate_seconds int" do
        empty = create_data_source
        dash = create_dashboard
        panel = create_panel(dash, widget_type: "comments", data_source: empty,
                             config: { quote_column: "quote" }.to_json)
        data = panel.data
        assert_equal [], data[:items]
        assert_kind_of Integer, data[:rotate_seconds]
      end

      test "rotate_seconds equals positive config value, else default 8" do
        d1 = panel_with(quote_column: "quote", rotate_seconds: 3).data
        assert_equal 3, d1[:rotate_seconds]
        d2 = panel_with(quote_column: "quote").data
        assert_equal 8, d2[:rotate_seconds]
        d3 = panel_with(quote_column: "quote", rotate_seconds: 0).data
        assert_equal 8, d3[:rotate_seconds]
        d4 = panel_with(quote_column: "quote", rotate_seconds: -5).data
        assert_equal 8, d4[:rotate_seconds]
      end

      test "partial renders every item's quote text" do
        panel = panel_with(quote_column: "quote", name_column: "author",
                           avatar_column: "pic")
        html = render_partial(panel)
        ["First", "Second", "Third (no name)", "Fourth (no avatar)"].each do |q|
          assert_includes html, q
        end
      end

      test "partial emits data attribute equal to rotate_seconds" do
        panel = panel_with(quote_column: "quote", rotate_seconds: 7)
        html = render_partial(panel)
        assert_match(/data-tiler-rotate-interval="7"/, html)
      end

      test "items missing :name omit name node, items missing :avatar omit img" do
        panel = panel_with(quote_column: "quote", name_column: "author",
                           avatar_column: "pic")
        html = render_partial(panel)
        # Fixture: 4 records — 3 have author (Alice, Bob, Dee), 3 have pic (a/b/c.png).
        assert_equal 3, html.scan(/class="tiler-comment-name"/).size
        assert_equal 3, html.scan(/class="tiler-comment-avatar"/).size
      end

      test "exactly one item has tiler-comment-active class on initial render" do
        panel = panel_with(quote_column: "quote")
        html = render_partial(panel)
        # Match only class-attribute occurrences (not the JS classList strings).
        assert_equal 1, html.scan(/class="[^"]*\btiler-comment-active\b[^"]*"/).size
      end

      test "rotator script gates with dataset flag" do
        panel = panel_with(quote_column: "quote")
        html = render_partial(panel)
        assert_includes html, "tilerCommentsStarted"
        assert_equal 1, html.scan(/setInterval\(/).size
      end

      test "avatar with javascript: scheme is dropped" do
        src = create_data_source
        dash = create_dashboard
        create_record(src, { quote: "Q", pic: "javascript:alert(1)" })
        panel = create_panel(dash, widget_type: "comments", data_source: src,
                             config: { quote_column: "quote", avatar_column: "pic" }.to_json)
        item = panel.data[:items].first
        assert_nil item[:avatar]
      end

      test "avatar with data: scheme is dropped" do
        src = create_data_source
        dash = create_dashboard
        create_record(src, { quote: "Q", pic: "data:image/png;base64,xxx" })
        panel = create_panel(dash, widget_type: "comments", data_source: src,
                             config: { quote_column: "quote", avatar_column: "pic" }.to_json)
        assert_nil panel.data[:items].first[:avatar]
      end

      test "avatar with http(s) scheme passes through" do
        src = create_data_source
        dash = create_dashboard
        create_record(src, { quote: "Q1", pic: "http://example.com/x.png" })
        create_record(src, { quote: "Q2", pic: "https://example.com/y.png" })
        panel = create_panel(dash, widget_type: "comments", data_source: src,
                             config: { quote_column: "quote", avatar_column: "pic" }.to_json)
        avatars = panel.data[:items].map { |i| i[:avatar] }
        assert_includes avatars, "http://example.com/x.png"
        assert_includes avatars, "https://example.com/y.png"
      end

      test "items with blank quote payload are dropped" do
        src = create_data_source
        dash = create_dashboard
        create_record(src, { quote: "Real", author: "A" })
        create_record(src, { author: "missing quote" }) # no quote key
        create_record(src, { quote: "" }) # blank quote
        panel = create_panel(dash, widget_type: "comments", data_source: src,
                             config: { quote_column: "quote", name_column: "author" }.to_json)
        items = panel.data[:items]
        quotes = items.map { |i| i[:quote] }
        assert_equal ["Real"], quotes
      end

      test "empty data source partial render does not raise" do
        empty = create_data_source
        dash = create_dashboard
        panel = create_panel(dash, widget_type: "comments", data_source: empty,
                             config: { quote_column: "quote" }.to_json)
        assert_nothing_raised { render_partial(panel) }
      end

      test "registry enumeration includes comments" do
        assert_includes Tiler.widgets.types, "comments"
        assert Tiler.widgets.options_for_select.any? { |label, type| type == "comments" && label == "Comments" }
      end
    end
  end
end
