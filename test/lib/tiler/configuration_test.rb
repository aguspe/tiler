require "test_helper"

module Tiler
  class ConfigurationTest < ActiveSupport::TestCase
    test "defaults are sane" do
      c = Configuration.new
      assert_equal "::ApplicationController", c.parent_controller
      assert_equal "tiler/application", c.layout
      assert_equal "X-Tiler-Token", c.webhook_token_header
      assert_equal 0, c.default_refresh_seconds
    end

    test "authorize_view default returns true" do
      c = Configuration.new
      assert_equal true, c.authorize_view.call(nil)
    end

    test "configure yields configuration" do
      Tiler.configure { |c| c.default_refresh_seconds = 42 }
      assert_equal 42, Tiler.configuration.default_refresh_seconds
    ensure
      Tiler.configure { |c| c.default_refresh_seconds = 0 }
    end
  end
end
