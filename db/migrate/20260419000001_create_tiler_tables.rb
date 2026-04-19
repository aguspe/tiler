class CreateTilerTables < ActiveRecord::Migration[7.1]
  def change
    create_table :tiler_dashboards do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.text    :description
      t.integer :refresh_seconds, null: false, default: 0
      t.timestamps
    end
    add_index :tiler_dashboards, :slug, unique: true
    add_index :tiler_dashboards, :name, unique: true

    create_table :tiler_data_sources do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.text    :description
      t.text    :schema_definition   # JSON array of { key, type, ... }
      t.text    :ingestion_methods   # JSON array of "webhook"/"manual"/"csv"
      t.string  :webhook_token
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :tiler_data_sources, :slug, unique: true
    add_index :tiler_data_sources, :name, unique: true
    add_index :tiler_data_sources, :webhook_token, unique: true

    create_table :tiler_data_records do |t|
      t.references :tiler_data_source, null: false, foreign_key: { to_table: :tiler_data_sources }, index: true
      t.text      :payload, null: false
      t.datetime  :recorded_at, null: false
      t.string    :source_ref
      t.string    :ingested_via, null: false, default: "manual"
      t.timestamps
    end
    add_index :tiler_data_records, :recorded_at

    create_table :tiler_panels do |t|
      t.references :tiler_dashboard,   null: false, foreign_key: { to_table: :tiler_dashboards },   index: true
      t.references :tiler_data_source, null: true,  foreign_key: { to_table: :tiler_data_sources }, index: true
      t.string  :title, null: false
      t.string  :widget_type, null: false
      t.integer :col_span, null: false, default: 1
      t.integer :position, null: false, default: 0
      t.text    :config        # JSON
      t.timestamps
    end
    add_index :tiler_panels, [ :tiler_dashboard_id, :position ]
  end
end
