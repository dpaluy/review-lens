class CreateInsightBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :insight_batches do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :batch_index, null: false
      t.integer :reviews_count, null: false
      t.jsonb :review_ids, null: false, default: []
      t.jsonb :summary, null: false, default: {}

      t.timestamps
    end

    add_index :insight_batches, [ :product_id, :batch_index ], unique: true
  end
end
