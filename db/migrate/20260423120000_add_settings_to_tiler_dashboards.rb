class AddSettingsToTilerDashboards < ActiveRecord::Migration[7.1]
  def change
    add_column :tiler_dashboards, :settings, :text
  end
end
