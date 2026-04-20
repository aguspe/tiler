require "test_helper"

module Tiler
  class DashboardTest < ActiveSupport::TestCase
    test "requires a name" do
      dash = Dashboard.new
      refute dash.valid?
      assert_includes dash.errors[:name], "can't be blank"
    end

    test "auto-generates slug from name" do
      dash = Dashboard.create!(name: "My Cool Board")
      assert_equal "my-cool-board", dash.slug
    end

    test "rejects duplicate slug" do
      Dashboard.create!(name: "Ops")
      dup = Dashboard.new(name: "OPS", slug: "ops")
      refute dup.valid?
    end

    test "slug format is strict" do
      assert_raises(ActiveRecord::RecordInvalid) { Dashboard.create!(name: "X", slug: "bad slug") }
    end

    test "refresh_seconds must be in allowed list" do
      d = Dashboard.new(name: "X", refresh_seconds: 7)
      refute d.valid?
    end

    test "uses slug for to_param" do
      d = Dashboard.create!(name: "My Board")
      assert_equal "my-board", d.to_param
    end

    test "panels ordered by y then x" do
      d = create_dashboard
      p1 = create_panel(d, y: 2, x: 0)
      p2 = create_panel(d, y: 0, x: 1)
      p3 = create_panel(d, y: 0, x: 0)
      assert_equal [ p3, p2, p1 ], d.panels.to_a
    end
  end
end
