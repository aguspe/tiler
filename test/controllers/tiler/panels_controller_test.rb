require "test_helper"

module Tiler
  class PanelsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @dash   = create_dashboard
      @source = create_data_source
    end

    test "GET new" do
      get new_dashboard_panel_path(@dash.slug)
      assert_response :success
    end

    test "POST create" do
      assert_difference "@dash.panels.count", 1 do
        post dashboard_panels_path(@dash.slug), params: {
          panel: { title: "Count", widget_type: "metric",
                   tiler_data_source_id: @source.id,
                   width: 6, height: 2, x: 0, y: 0,
                   config: { aggregation: "count" }.to_json }
        }
      end
      assert_redirected_to dashboard_path(@dash.slug)
    end

    test "POST create rejects unknown widget_type" do
      post dashboard_panels_path(@dash.slug), params: {
        panel: { title: "X", widget_type: "not_a_widget", width: 6, height: 2, x: 0, y: 0 }
      }
      assert_response :unprocessable_entity
    end

    test "GET preview renders the widget partial" do
      p = create_panel(@dash, widget_type: "metric", data_source: @source,
                       config: { aggregation: "count" }.to_json)
      create_record(@source, { status: "ok" })
      create_record(@source, { status: "ok" })
      get preview_dashboard_panel_path(@dash.slug, p)
      assert_response :success
      assert_match "tiler-metric-value", @response.body
    end

    test "GET preview with clock widget (no data source)" do
      p = create_panel(@dash, widget_type: "clock", data_source: nil)
      get preview_dashboard_panel_path(@dash.slug, p)
      assert_response :success
      assert_match "tiler-clock", @response.body
    end

    test "DELETE removes panel" do
      p = create_panel(@dash)
      assert_difference "@dash.panels.count", -1 do
        delete dashboard_panel_path(@dash.slug, p)
      end
    end

    test "POST create rejects forged widget_type with 422" do
      dash = create_dashboard
      assert_no_difference -> { dash.panels.count } do
        post dashboard_panels_path(dash.slug),
             params: { panel: { widget_type: "../etc/passwd", title: "X",
                                x: 0, y: 0, width: 3, height: 2, config: "{}" } },
             as: :json
      end
      assert_response :unprocessable_entity
    end

    test "POST create rejects blank widget_type with 422" do
      dash = create_dashboard
      assert_no_difference -> { dash.panels.count } do
        post dashboard_panels_path(dash.slug),
             params: { panel: { widget_type: "", title: "X",
                                x: 0, y: 0, width: 3, height: 2, config: "{}" } },
             as: :json
      end
      assert_response :unprocessable_entity
    end

    test "POST create accepts registered widget_type" do
      dash = create_dashboard
      assert_difference -> { dash.panels.count }, 1 do
        post dashboard_panels_path(dash.slug),
             params: { panel: { widget_type: "image", title: "Logo",
                                x: 0, y: 0, width: 3, height: 2, config: "{}" } },
             as: :json
      end
      assert_response :created
    end
  end
end
