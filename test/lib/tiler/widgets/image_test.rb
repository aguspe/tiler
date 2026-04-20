require "test_helper"

module Tiler
  module Widgets
    class ImageTest < ActionView::TestCase
      setup do
        @dash = create_dashboard
      end

      def panel_with(config = {})
        create_panel(@dash, widget_type: "image", config: config.to_json)
      end

      def render_partial(panel)
        render partial: "tiler/widgets/image", locals: { panel: panel, data: panel.data }
      end

      test "registry returns the registered class with documented attributes" do
        klass = Tiler.widgets["image"]
        assert_equal Tiler::Widgets::Image, klass
        assert_equal "image", klass.type
        assert_equal "Image", klass.label
        assert_equal "tiler/widgets/image", klass.partial
        assert_nil klass.query_class
      end

      test "data returns hash with url/alt/fit for typical config" do
        panel = panel_with(url: "https://example.com/x.png", alt: "X", fit: "cover")
        data = panel.data
        assert_equal "https://example.com/x.png", data[:url]
        assert_equal "X", data[:alt]
        assert_equal "cover", data[:fit]
      end

      test "fit defaults to contain when missing" do
        panel = panel_with(url: "https://example.com/x.png")
        assert_equal "contain", panel.data[:fit]
      end

      test "fit defaults to contain when blank" do
        panel = panel_with(url: "https://example.com/x.png", fit: "")
        assert_equal "contain", panel.data[:fit]
      end

      test "partial renders one img with src and alt when url present" do
        panel = panel_with(url: "https://example.com/x.png", alt: "X", fit: "cover")
        html = render_partial(panel)
        assert_equal 1, html.scan(/<img\b/).size
        assert_includes html, 'src="https://example.com/x.png"'
        assert_includes html, 'alt="X"'
        assert_match(/object-fit:\s*cover/, html)
      end

      test "partial renders empty alt when alt omitted" do
        panel = panel_with(url: "https://example.com/x.png")
        html = render_partial(panel)
        assert_includes html, 'alt=""'
      end

      test "partial renders placeholder and zero img tags when url blank" do
        panel = panel_with(url: "")
        html = render_partial(panel)
        assert_equal 0, html.scan(/<img\b/).size
        assert_match(/tiler-muted/, html)
      end

      test "partial does not raise when url missing entirely" do
        panel = panel_with({})
        html = render_partial(panel)
        assert_equal 0, html.scan(/<img\b/).size
      end

      test "registry enumeration includes image" do
        assert_includes Tiler.widgets.types, "image"
        assert Tiler.widgets.options_for_select.any? { |label, type| type == "image" && label == "Image" }
      end

      test "fit with malicious value falls back to contain" do
        panel = panel_with(url: "https://example.com/x.png", fit: "contain; background:url(http://attacker)")
        data = panel.data
        assert_equal "contain", data[:fit]
        html = render_partial(panel)
        refute_match(/background\s*:/, html)
      end

      test "fit unknown enum falls back to contain" do
        panel = panel_with(url: "https://example.com/x.png", fit: "stretch")
        assert_equal "contain", panel.data[:fit]
      end

      test "url with javascript scheme renders placeholder" do
        panel = panel_with(url: "javascript:alert(1)")
        html = render_partial(panel)
        assert_equal 0, html.scan(/<img\b/).size
        assert_match(/tiler-muted/, html)
      end

      test "url with data scheme renders placeholder" do
        panel = panel_with(url: "data:image/svg+xml,<svg></svg>")
        html = render_partial(panel)
        assert_equal 0, html.scan(/<img\b/).size
      end

      test "http and https url pass through" do
        http_panel = panel_with(url: "http://example.com/x.png")
        https_panel = panel_with(url: "https://example.com/y.png")
        assert_includes render_partial(http_panel), 'src="http://example.com/x.png"'
        assert_includes render_partial(https_panel), 'src="https://example.com/y.png"'
      end

      test "url with file scheme renders placeholder" do
        panel = panel_with(url: "file:///etc/passwd")
        html = render_partial(panel)
        assert_equal 0, html.scan(/<img\b/).size
        assert_match(/tiler-muted/, html)
      end

      test "url with no scheme (bare string) renders placeholder" do
        panel = panel_with(url: "x.png")
        html = render_partial(panel)
        assert_equal 0, html.scan(/<img\b/).size
      end
    end
  end
end
