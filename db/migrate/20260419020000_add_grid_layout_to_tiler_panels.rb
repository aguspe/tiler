class AddGridLayoutToTilerPanels < ActiveRecord::Migration[7.1]
  def up
    rename_column :tiler_panels, :col_span, :width
    add_column :tiler_panels, :height, :integer, null: false, default: 2
    add_column :tiler_panels, :x,      :integer, null: false, default: 0
    add_column :tiler_panels, :y,      :integer, null: false, default: 0

    execute "UPDATE tiler_panels SET width = 12 WHERE width = 2"
    execute "UPDATE tiler_panels SET width = 6  WHERE width = 1"

    remove_index  :tiler_panels, [ :tiler_dashboard_id, :position ] rescue nil
    remove_column :tiler_panels, :position
    add_index     :tiler_panels, [ :tiler_dashboard_id, :y, :x ]
  end

  def down
    add_column   :tiler_panels, :position, :integer, null: false, default: 0
    remove_index :tiler_panels, [ :tiler_dashboard_id, :y, :x ] rescue nil
    remove_column :tiler_panels, :x
    remove_column :tiler_panels, :y
    remove_column :tiler_panels, :height
    execute "UPDATE tiler_panels SET width = 2 WHERE width >= 7"
    execute "UPDATE tiler_panels SET width = 1 WHERE width <= 6"
    rename_column :tiler_panels, :width, :col_span
  end
end
