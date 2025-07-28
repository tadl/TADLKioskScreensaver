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

ActiveRecord::Schema[7.1].define(version: 2025062600000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "kiosk_groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "location_shortname"
    t.index ["location_shortname"], name: "index_kiosk_groups_on_location_shortname"
    t.index ["slug"], name: "index_kiosk_groups_on_slug", unique: true
  end

  create_table "kiosk_groups_user_permissions", id: false, force: :cascade do |t|
    t.bigint "user_permission_id", null: false
    t.bigint "kiosk_group_id", null: false
  end

  create_table "kiosk_sessions", force: :cascade do |t|
    t.string "kiosk_code", null: false
    t.string "host"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.integer "slide_fetch_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kiosk_code", "host", "started_at"], name: "index_kiosk_sessions_on_kiosk_code_and_host_and_started_at"
  end

  create_table "kiosks", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.string "catalog_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "kiosk_group_id"
    t.string "location"
    t.index ["kiosk_group_id"], name: "index_kiosks_on_kiosk_group_id"
    t.index ["slug"], name: "index_kiosks_on_slug", unique: true
  end

  create_table "kiosks_slides", id: false, force: :cascade do |t|
    t.bigint "slide_id", null: false
    t.bigint "kiosk_id", null: false
  end

  create_table "permissions", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "slides", force: :cascade do |t|
    t.string "title"
    t.string "link"
    t.integer "display_seconds"
    t.date "start_date"
    t.date "end_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "fallback", default: false, null: false
  end

  create_table "user_permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "permission_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_user_permissions_on_permission_id"
    t.index ["user_id"], name: "index_user_permissions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.boolean "admin", default: false, null: false
    t.string "image_url"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "kiosks", "kiosk_groups"
  add_foreign_key "user_permissions", "permissions"
  add_foreign_key "user_permissions", "users"
end
