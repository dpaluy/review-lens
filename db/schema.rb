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

ActiveRecord::Schema[8.1].define(version: 2026_06_26_211000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_ai_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_ai_models_on_family"
    t.index ["modalities"], name: "index_ai_models_on_modalities", using: :gin
    t.index ["provider", "model_id"], name: "index_ai_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_ai_models_on_provider"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "ai_model_id"
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.text "content"
    t.json "content_raw"
    t.bigint "conversation_id", null: false
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.bigint "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["ai_model_id"], name: "index_chat_messages_on_ai_model_id"
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
    t.index ["role"], name: "index_chat_messages_on_role"
    t.index ["tool_call_id"], name: "index_chat_messages_on_tool_call_id"
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "ai_model_id"
    t.datetime "cleared_at"
    t.datetime "created_at", null: false
    t.bigint "product_id"
    t.datetime "updated_at", null: false
    t.index ["ai_model_id"], name: "index_conversations_on_ai_model_id"
    t.index ["product_id"], name: "index_conversations_on_product_id"
    t.index ["product_id"], name: "index_conversations_on_unique_product_id", unique: true, where: "(product_id IS NOT NULL)"
  end

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

  create_table "insight_batches", force: :cascade do |t|
    t.integer "batch_index", null: false
    t.datetime "created_at", null: false
    t.bigint "product_id", null: false
    t.jsonb "review_ids", default: [], null: false
    t.integer "reviews_count", null: false
    t.jsonb "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "batch_index"], name: "index_insight_batches_on_product_id_and_batch_index", unique: true
    t.index ["product_id"], name: "index_insight_batches_on_product_id"
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
    t.text "source_url"
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
    t.text "source_url"
    t.text "title"
    t.datetime "updated_at", null: false
    t.index ["product_id", "content_hash"], name: "index_reviews_on_product_id_and_content_hash", unique: true
    t.index ["product_id", "external_review_id"], name: "index_reviews_on_product_id_and_external_review_id", unique: true, where: "(external_review_id IS NOT NULL)"
    t.index ["product_id"], name: "index_reviews_on_product_id"
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["sentiment"], name: "index_reviews_on_sentiment"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.bigint "chat_message_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_message_id"], name: "index_tool_calls_on_chat_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chat_messages", "ai_models"
  add_foreign_key "chat_messages", "conversations"
  add_foreign_key "chat_messages", "tool_calls"
  add_foreign_key "conversations", "ai_models"
  add_foreign_key "conversations", "products"
  add_foreign_key "ingestion_runs", "products"
  add_foreign_key "insight_batches", "products"
  add_foreign_key "reviews", "products"
  add_foreign_key "tool_calls", "chat_messages"
end
