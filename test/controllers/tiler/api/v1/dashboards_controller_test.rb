require "test_helper"

module Tiler
  module Api
    module V1
      class DashboardsControllerTest < ActionDispatch::IntegrationTest
        include Engine.routes.url_helpers

        test "POST /tiler/api/v1/dashboards creates a dashboard from JSON" do
          assert_difference -> { Tiler::Dashboard.count }, 1 do
            post api_v1_dashboards_path,
                 params: { dashboard: { name: "API Created", refresh_seconds: 30 } },
                 as: :json
          end
          assert_response :created
          body = JSON.parse(response.body)
          assert_equal "API Created", body["name"]
          assert_equal "api-created", body["slug"]
          assert_equal 30, body["refresh_seconds"]
        end

        test "POST rejects missing name" do
          assert_no_difference -> { Tiler::Dashboard.count } do
            post api_v1_dashboards_path,
                 params: { dashboard: { refresh_seconds: 30 } },
                 as: :json
          end
          assert_response :unprocessable_entity
          body = JSON.parse(response.body)
          assert body["errors"].present?
        end

        test "GET /tiler/api/v1/dashboards/:slug returns dashboard JSON" do
          dash = create_dashboard(name: "Read Me")
          get api_v1_dashboard_path(dash.slug)
          assert_response :ok
          body = JSON.parse(response.body)
          assert_equal dash.slug, body["slug"]
          assert_equal "Read Me", body["name"]
        end

        test "GET /tiler/api/v1/dashboards lists dashboards" do
          create_dashboard(name: "A")
          create_dashboard(name: "B")
          get api_v1_dashboards_path
          assert_response :ok
          body = JSON.parse(response.body)
          assert_kind_of Array, body
          assert_operator body.size, :>=, 2
        end

        test "PATCH /tiler/api/v1/dashboards/:slug/settings updates settings JSON" do
          dash = create_dashboard(name: "Settings target")
          patch settings_api_v1_dashboard_path(dash.slug),
                params: { settings: { tv_mode: true } },
                as: :json
          assert_response :ok
          dash.reload
          assert_equal true, dash.settings_hash["tv_mode"]
          body = JSON.parse(response.body)
          assert_equal true, body["settings"]["tv_mode"]
        end

        test "PATCH settings rejects unknown dashboard" do
          patch settings_api_v1_dashboard_path("not-a-real-slug"),
                params: { settings: { tv_mode: true } },
                as: :json
          assert_response :not_found
        end

        test "DELETE /tiler/api/v1/dashboards/:slug deletes dashboard" do
          dash = create_dashboard(name: "Delete me")
          assert_difference -> { Tiler::Dashboard.count }, -1 do
            delete api_v1_dashboard_path(dash.slug)
          end
          assert_response :no_content
        end
      end
    end
  end
end
