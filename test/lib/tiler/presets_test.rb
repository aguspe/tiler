require "test_helper"
require "tiler/presets"

# Each preset must be self-contained and idempotent: running it twice does
# not duplicate dashboards, panels, or sample records.
module Tiler
  class PresetsTest < ActiveSupport::TestCase
    setup do
      Tiler::Dashboard.where(slug: %w[demo test_automation commerce]).destroy_all
      Tiler::DataSource.where(slug: %w[demo_requests demo_quotes test_runs orders sessions]).destroy_all
    end

    test "registry exposes the three named presets" do
      names = Tiler::Presets.names
      %w[default test_automation commerce].each { |n| assert_includes names, n }
    end

    test "fetching an unknown preset raises with a helpful message" do
      err = assert_raises(ArgumentError) { Tiler::Presets.fetch("nope") }
      assert_match(/unknown preset/i, err.message)
      assert_match(/default|commerce|test_automation/, err.message)
    end

    Presets::REGISTRY.each do |name, klass|
      define_method "test_#{name}_preset_creates_dashboard_+_panels_+_data_sources" do
        Tiler::Presets.run!(name)
        dash = Tiler::Dashboard.find_by(slug: klass.new.slug)
        assert dash, "#{name} preset must create the #{klass.new.slug} dashboard"
        assert dash.panels.size > 0, "#{name} preset must create at least one panel"
        # Every panel must reference a registered widget.
        dash.panels.each do |p|
          assert Tiler.widgets[p.widget_type], "#{name} -> panel '#{p.title}' uses unregistered widget #{p.widget_type}"
        end
      end

      define_method "test_#{name}_preset_is_idempotent" do
        Tiler::Presets.run!(name)
        first_count = Tiler::Dashboard.count
        first_panels = Tiler::Dashboard.find_by(slug: klass.new.slug).panels.size
        Tiler::Presets.run!(name)
        assert_equal first_count, Tiler::Dashboard.count, "running twice must not create extra dashboards"
        assert_equal first_panels, Tiler::Dashboard.find_by(slug: klass.new.slug).panels.size,
                     "running twice must not duplicate panels"
      end

      define_method "test_#{name}_preset_seeds_records_for_visualisation" do
        Tiler::Presets.run!(name)
        # Every data source the preset created should have at least some
        # records so the dashboard isn't a sea of empty states. (Default
        # preset's quotes source has only 5 fixed quotes, so we use ≥1.)
        Tiler::Presets.fetch(name).new.tap do |p|
          p.send(:data_sources!).each_value do |ds|
            assert ds.data_records.count >= 1, "#{name}: source #{ds.slug} has no sample records"
          end
        end
      end
    end
  end
end
