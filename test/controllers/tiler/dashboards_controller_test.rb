require "test_helper"

module Tiler
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "GET index renders" do
      get dashboards_path
      assert_response :success
      assert_match "Dashboards", @response.body
    end

    test "GET show by slug" do
      d = create_dashboard(name: "Ops")
      get dashboard_path(d.slug)
      assert_response :success
      assert_match "Ops", @response.body
    end

    test "POST create with valid params" do
      assert_difference "Tiler::Dashboard.count", 1 do
        post dashboards_path, params: { dashboard: { name: "New Board", refresh_seconds: 60 } }
      end
      assert_redirected_to dashboard_path(Tiler::Dashboard.last.slug)
    end

    test "POST create with invalid params re-renders" do
      post dashboards_path, params: { dashboard: { name: "" } }
      assert_response :unprocessable_entity
    end

    test "PATCH layout persists x/y/w/h" do
      d = create_dashboard
      p = create_panel(d, x: 0, y: 0, width: 3, height: 2)
      patch layout_dashboard_path(d.slug),
            params: { items: [ { id: p.id, x: 5, y: 2, w: 4, h: 3 } ] },
            as: :json
      assert_response :success
      p.reload
      assert_equal 5, p.x
      assert_equal 2, p.y
      assert_equal 4, p.width
      assert_equal 3, p.height
    end

    test "PATCH layout clamps width to 1..12" do
      d = create_dashboard
      p = create_panel(d)
      patch layout_dashboard_path(d.slug),
            params: { items: [ { id: p.id, x: 0, y: 0, w: 99, h: 999 } ] },
            as: :json
      p.reload
      assert_equal 12, p.width
      assert_equal 12, p.height
    end

    test "DELETE destroy" do
      d = create_dashboard
      assert_difference "Tiler::Dashboard.count", -1 do
        delete dashboard_path(d.slug)
      end
    end
  end
end
