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

ActiveRecord::Schema[8.1].define(version: 2026_06_25_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ingestion_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.datetime "finished_at"
    t.integer "pages_attempted", default: 0, null: false
    t.integer "pages_succeeded", default: 0, null: false
    t.string "parser_version"
    t.bigint "product_id", null: false
    t.jsonb "raw_fetch_metadata", default: {}, null: false
    t.integer "reviews_found", default: 0, null: false
    t.integer "reviews_imported", default: 0, null: false
    t.integer "reviews_skipped", default: 0, null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.jsonb "warnings", default: [], null: false
    t.index ["product_id"], name: "index_ingestion_runs_on_product_id"
    t.index ["status"], name: "index_ingestion_runs_on_status"
  end

  create_table "products", force: :cascade do |t|
    t.decimal "average_rating", precision: 3, scale: 2
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.text "ingestion_error"
    t.string "ingestion_status", default: "pending", null: false
    t.jsonb "ingestion_summary", default: {}, null: false
    t.string "name"
    t.datetime "newest_review_at"
    t.datetime "oldest_review_at"
    t.string "platform", null: false
    t.jsonb "rating_distribution", default: {}, null: false
    t.integer "reviews_count", default: 0, null: false
    t.jsonb "sentiment_distribution", default: {}, null: false
    t.text "source_url", null: false
    t.datetime "updated_at", null: false
    t.index ["ingestion_status"], name: "index_products_on_ingestion_status"
    t.index ["platform", "external_id"], name: "index_products_on_platform_and_external_id", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.text "body", null: false
    t.string "content_hash", null: false
    t.datetime "created_at", null: false
    t.string "external_review_id"
    t.integer "helpful_count"
    t.bigint "product_id", null: false
    t.decimal "rating", precision: 3, scale: 2
    t.jsonb "raw_payload", default: {}, null: false
    t.datetime "review_date"
    t.string "reviewer_company_size"
    t.string "reviewer_label"
    t.string "reviewer_role"
    t.string "sentiment", default: "unknown", null: false
    t.text "source_url", null: false
    t.text "title"
    t.datetime "updated_at", null: false
    t.index ["product_id", "content_hash"], name: "index_reviews_on_product_id_and_content_hash", unique: true
    t.index ["product_id", "external_review_id"], name: "index_reviews_on_product_id_and_external_review_id", unique: true, where: "(external_review_id IS NOT NULL)"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["sentiment"], name: "index_reviews_on_sentiment"
  end

  add_foreign_key "ingestion_runs", "products"
  add_foreign_key "reviews", "products"
end
