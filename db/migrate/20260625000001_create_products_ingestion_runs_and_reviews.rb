class CreateProductsIngestionRunsAndReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :platform, null: false
      t.text :source_url, null: false
      t.string :external_id, null: false
      t.string :name
      t.string :ingestion_status, null: false, default: "pending"
      t.text :ingestion_error
      t.integer :reviews_count, null: false, default: 0
      t.decimal :average_rating, precision: 3, scale: 2
      t.jsonb :rating_distribution, null: false, default: {}
      t.jsonb :sentiment_distribution, null: false, default: {}
      t.datetime :oldest_review_at
      t.datetime :newest_review_at
      t.jsonb :ingestion_summary, null: false, default: {}

      t.timestamps
    end

    add_index :products, [ :platform, :external_id ], unique: true
    add_index :products, :ingestion_status

    create_table :ingestion_runs do |t|
      t.references :product, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :pages_attempted, null: false, default: 0
      t.integer :pages_succeeded, null: false, default: 0
      t.integer :reviews_found, null: false, default: 0
      t.integer :reviews_imported, null: false, default: 0
      t.integer :reviews_skipped, null: false, default: 0
      t.string :parser_version
      t.jsonb :warnings, null: false, default: []
      t.text :error
      t.jsonb :raw_fetch_metadata, null: false, default: {}

      t.timestamps
    end

    add_index :ingestion_runs, :status

    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.string :external_review_id
      t.string :content_hash, null: false
      t.text :source_url, null: false
      t.decimal :rating, precision: 3, scale: 2
      t.string :sentiment, null: false, default: "unknown"
      t.text :title
      t.text :body, null: false
      t.string :reviewer_label
      t.string :reviewer_role
      t.string :reviewer_company_size
      t.datetime :review_date
      t.integer :helpful_count
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :reviews, [ :product_id, :external_review_id ], unique: true, where: "external_review_id IS NOT NULL"
    add_index :reviews, [ :product_id, :content_hash ], unique: true
    add_index :reviews, :sentiment
    add_index :reviews, :rating
  end
end
