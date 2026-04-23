require "test_helper"

# Clock — config-only widget; honors `show_date` per catalog (default true).
module Tiler
  class WidgetsClockTest < ActionView::TestCase
    setup do
      @dash = create_dashboard
    end

    def panel(config = {})
      create_panel(@dash, widget_type: "clock", config: config.to_json)
    end

    def render_partial(panel)
      render partial: "tiler/widgets/clock", locals: { panel: panel, data: panel.data }
    end

    test "show_date defaults to true" do
      assert_equal true, panel.data[:show_date]
    end

    test "show_date false hides the date element in the partial" do
      html = render_partial(panel(show_date: false))
      refute_match(/tiler-clock-date/, html, "date element must be omitted when show_date=false")
    end

    test "show_date true (default) renders the date element" do
      html = render_partial(panel)
      assert_match(/tiler-clock-date/, html)
    end

    test "show_date true explicitly also renders the date element" do
      html = render_partial(panel(show_date: true))
      assert_match(/tiler-clock-date/, html)
    end
  end
end
