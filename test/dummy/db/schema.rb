# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_19_020000) do
  create_table "tiler_dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "refresh_seconds", default: 0, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tiler_dashboards_on_name", unique: true
    t.index ["slug"], name: "index_tiler_dashboards_on_slug", unique: true
  end

  create_table "tiler_data_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ingested_via", default: "manual", null: false
    t.text "payload", null: false
    t.datetime "recorded_at", null: false
    t.string "source_ref"
    t.integer "tiler_data_source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recorded_at"], name: "index_tiler_data_records_on_recorded_at"
    t.index ["tiler_data_source_id"], name: "index_tiler_data_records_on_tiler_data_source_id"
  end

  create_table "tiler_data_sources", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.text "ingestion_methods"
    t.string "name", null: false
    t.text "schema_definition"
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_token"
    t.index ["name"], name: "index_tiler_data_sources_on_name", unique: true
    t.index ["slug"], name: "index_tiler_data_sources_on_slug", unique: true
    t.index ["webhook_token"], name: "index_tiler_data_sources_on_webhook_token", unique: true
  end

  create_table "tiler_panels", force: :cascade do |t|
    t.text "config"
    t.datetime "created_at", null: false
    t.integer "height", default: 2, null: false
    t.integer "tiler_dashboard_id", null: false
    t.integer "tiler_data_source_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "widget_type", null: false
    t.integer "width", default: 1, null: false
    t.integer "x", default: 0, null: false
    t.integer "y", default: 0, null: false
    t.index ["tiler_dashboard_id", "y", "x"], name: "index_tiler_panels_on_tiler_dashboard_id_and_y_and_x"
    t.index ["tiler_dashboard_id"], name: "index_tiler_panels_on_tiler_dashboard_id"
    t.index ["tiler_data_source_id"], name: "index_tiler_panels_on_tiler_data_source_id"
  end

  add_foreign_key "tiler_data_records", "tiler_data_sources"
  add_foreign_key "tiler_panels", "tiler_dashboards"
  add_foreign_key "tiler_panels", "tiler_data_sources"
end
