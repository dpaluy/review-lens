class InsightBatch < ApplicationRecord
  belongs_to :product

  validates :batch_index, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :batch_index, uniqueness: { scope: :product_id }
  validates :reviews_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :review_ids, :summary, presence: true
  validate :review_ids_are_array
  validate :summary_is_hash

  private
    def review_ids_are_array
      errors.add :review_ids, "must be an array" unless review_ids.is_a?(Array)
    end

    def summary_is_hash
      errors.add :summary, "must be an object" unless summary.is_a?(Hash)
    end
end
