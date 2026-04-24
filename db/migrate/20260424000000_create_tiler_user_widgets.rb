class CreateTilerUserWidgets < ActiveRecord::Migration[7.1]
  def change
    create_table :tiler_user_widgets do |t|
      t.string :slug,    null: false
      t.string :label,   null: false
      t.text   :template, null: false # Liquid template
      # data_kind:
      #   "config_only" — widget pulls from panel.config only, no data source
      #   "query"       — widget reads aggregated payloads from a data source
      t.string :data_kind, null: false, default: "config_only"
      t.text :query_definition  # JSON: { source_slug, time_window, group_by, value_column, aggregation }
      t.text :default_config    # JSON: pre-populated panel.config
      t.integer :default_w, null: false, default: 4
      t.integer :default_h, null: false, default: 3
      t.timestamps
    end
    add_index :tiler_user_widgets, :slug, unique: true
  end
end
