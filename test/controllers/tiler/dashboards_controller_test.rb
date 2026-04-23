require "test_helper"

module Tiler
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @dash = create_dashboard
    end

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

    test "PATCH layout clamps negative x to 0" do
      panel = create_panel(@dash, x: 5, y: 0)
      patch layout_dashboard_path(@dash),
            params: { items: [ { id: panel.id, x: -100, y: 2, w: 4, h: 2 } ] },
            as: :json
      assert_response :ok
      panel.reload
      assert_equal 0, panel.x
    end

    test "PATCH layout clamps x above 11 to 11" do
      panel = create_panel(@dash, x: 0, y: 0)
      patch layout_dashboard_path(@dash),
            params: { items: [ { id: panel.id, x: 99, y: 2, w: 4, h: 2 } ] },
            as: :json
      assert_response :ok
      panel.reload
      assert_equal 11, panel.x
    end

    test "PATCH layout clamps negative y to 0" do
      panel = create_panel(@dash, x: 0, y: 5)
      patch layout_dashboard_path(@dash),
            params: { items: [ { id: panel.id, x: 0, y: -5, w: 4, h: 2 } ] },
            as: :json
      assert_response :ok
      panel.reload
      assert_equal 0, panel.y
    end

    test "PATCH layout returns 400 with JSON error for non-array items" do
      patch layout_dashboard_path(@dash),
            params: { items: "not-an-array" },
            as: :json
      assert_response :bad_request
      body = JSON.parse(response.body)
      assert body["error"].present?
    end

    test "PATCH layout skips items with missing id and counts skipped" do
      panel = create_panel(@dash, x: 0, y: 0)
      patch layout_dashboard_path(@dash),
            params: { items: [
              { id: panel.id, x: 1, y: 1, w: 4, h: 2 },
              { x: 2, y: 2, w: 4, h: 2 } # no id
            ] },
            as: :json
      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal 1, body["applied"]
      assert_equal 1, body["skipped"]
    end

    test "PATCH layout response shape is {applied, skipped}" do
      panel = create_panel(@dash, x: 0, y: 0)
      patch layout_dashboard_path(@dash),
            params: { items: [ { id: panel.id, x: 0, y: 0, w: 4, h: 2 } ] },
            as: :json
      assert_response :ok
      body = JSON.parse(response.body)
      assert_kind_of Integer, body["applied"]
      assert_kind_of Integer, body["skipped"]
    end
  end
end
