require "test_helper"

# Per-dashboard personalization: 4 theme-token accessors (page_bg, tile_bg,
# tile_header_bg, gutter_bg) + logo_url, all stored in the settings JSON.
module Tiler
  class DashboardPersonalizationTest < ActiveSupport::TestCase
    setup do
      @dash = create_dashboard
    end

    Tiler::Dashboard::THEME_KEYS.each do |key|
      define_method "test_#{key}_returns_stored_hex_when_valid" do
        @dash.update!(settings: { key => "#1a2b3c" }.to_json)
        assert_equal "#1a2b3c", @dash.public_send(key)
      end

      define_method "test_#{key}_accepts_short_hex" do
        @dash.update!(settings: { key => "#abc" }.to_json)
        assert_equal "#abc", @dash.public_send(key)
      end

      define_method "test_#{key}_accepts_hex_with_alpha" do
        @dash.update!(settings: { key => "#1a2b3c80" }.to_json)
        assert_equal "#1a2b3c80", @dash.public_send(key)
      end

      define_method "test_#{key}_rejects_malformed_values" do
        [ "rgb(0,0,0)", "red", "1a2b3c", "#zzz", "#12", "javascript:alert(1)" ].each do |bad|
          @dash.update!(settings: { key => bad }.to_json)
          assert_nil @dash.public_send(key), "#{bad.inspect} should be rejected for #{key}"
        end
      end

      define_method "test_#{key}_is_nil_when_unset" do
        assert_nil @dash.public_send(key)
      end
    end

    test "theme_inline_style emits one CSS custom-property per set token" do
      @dash.update!(settings: {
        page_bg: "#111", tile_bg: "#222",
        tile_header_bg: "#333", gutter_bg: "#444"
      }.to_json)
      style = @dash.theme_inline_style
      assert_includes style, "--paper: #111;"
      assert_includes style, "--paper-2: #222;"
      assert_includes style, "--paper-3: #333;"
      assert_includes style, "--border: #444;"
    end

    test "theme_inline_style omits unset tokens (partial theming)" do
      @dash.update!(settings: { page_bg: "#abc" }.to_json)
      style = @dash.theme_inline_style
      assert_includes style, "--paper: #abc;"
      refute_includes style, "--paper-2"
      refute_includes style, "--paper-3"
      refute_includes style, "--border"
    end

    test "theme_inline_style is empty when nothing themed" do
      assert_equal "", @dash.theme_inline_style
    end

    test "logo_url returns the stored URL when http(s)" do
      @dash.update!(settings: { logo_url: "https://example.com/logo.png" }.to_json)
      assert_equal "https://example.com/logo.png", @dash.logo_url
    end

    test "logo_url accepts plain http://" do
      @dash.update!(settings: { logo_url: "http://example.com/logo.png" }.to_json)
      assert_equal "http://example.com/logo.png", @dash.logo_url
    end

    test "logo_url rejects javascript:, data:, file: schemes" do
      [ "javascript:alert(1)", "data:image/png;base64,AAAA", "file:///etc/passwd",
        "ftp://example.com/x.png", "//example.com/x.png" ].each do |bad|
        @dash.update!(settings: { logo_url: bad }.to_json)
        assert_nil @dash.logo_url, "#{bad.inspect} should be rejected"
      end
    end

    test "logo_url is nil when blank or missing" do
      assert_nil @dash.logo_url
      @dash.update!(settings: { logo_url: "" }.to_json)
      assert_nil @dash.logo_url
    end

    test "personalization keys round-trip alongside other settings (no overwrite)" do
      @dash.update!(settings: { tv_mode: true }.to_json)
      merged = @dash.settings_hash.merge(
        "page_bg"        => "#abcdef",
        "tile_bg"        => "#fedcba",
        "tile_header_bg" => "#123456",
        "gutter_bg"      => "#654321",
        "logo_url"       => "https://x/l.png"
      )
      @dash.update!(settings: merged.to_json)
      assert_equal "#abcdef",         @dash.page_bg
      assert_equal "#fedcba",         @dash.tile_bg
      assert_equal "#123456",         @dash.tile_header_bg
      assert_equal "#654321",         @dash.gutter_bg
      assert_equal "https://x/l.png", @dash.logo_url
      assert_equal true,              @dash.tv_mode?
    end
  end
end
