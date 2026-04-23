require "test_helper"

# Per-dashboard personalization (F2): background_color + logo_url helpers
# parse and validate values stored in the settings JSON column.
module Tiler
  class DashboardPersonalizationTest < ActiveSupport::TestCase
    setup do
      @dash = create_dashboard
    end

    test "background_color returns the stored hex when valid (#rrggbb)" do
      @dash.update!(settings: { background_color: "#1a2b3c" }.to_json)
      assert_equal "#1a2b3c", @dash.background_color
    end

    test "background_color accepts short hex (#abc)" do
      @dash.update!(settings: { background_color: "#abc" }.to_json)
      assert_equal "#abc", @dash.background_color
    end

    test "background_color accepts hex with alpha (#rrggbbaa)" do
      @dash.update!(settings: { background_color: "#1a2b3c80" }.to_json)
      assert_equal "#1a2b3c80", @dash.background_color
    end

    test "background_color rejects malformed values (returns nil for fallback)" do
      [ "rgb(0,0,0)", "red", "1a2b3c", "#zzz", "#12", "javascript:alert(1)" ].each do |bad|
        @dash.update!(settings: { background_color: bad }.to_json)
        assert_nil @dash.background_color, "#{bad.inspect} should be rejected"
      end
    end

    test "background_color is nil when unset" do
      assert_nil @dash.background_color
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
      merged = @dash.settings_hash.merge("background_color" => "#abcdef",
                                         "logo_url" => "https://x/l.png")
      @dash.update!(settings: merged.to_json)
      assert_equal "#abcdef",            @dash.background_color
      assert_equal "https://x/l.png",    @dash.logo_url
      assert_equal true,                 @dash.tv_mode?
    end
  end
end
