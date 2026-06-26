require "test_helper"

class InsightBatchTest < ActiveSupport::TestCase
  test "belongs to product" do
    insight_batch = InsightBatch.new(
      product: products(:example),
      batch_index: 0,
      reviews_count: 1,
      review_ids: [ reviews(:positive).id ],
      summary: summary
    )

    assert_predicate insight_batch, :valid?
  end

  test "requires batch index reviews count review ids and summary" do
    insight_batch = InsightBatch.new(product: products(:example))

    assert_not insight_batch.valid?
    assert_includes insight_batch.errors[:batch_index], "can't be blank"
    assert_includes insight_batch.errors[:reviews_count], "can't be blank"
    assert_includes insight_batch.errors[:review_ids], "can't be blank"
    assert_includes insight_batch.errors[:summary], "can't be blank"
  end

  test "enforces unique batch index per product" do
    product = products(:example)
    product.insight_batches.create!(
      batch_index: 0,
      reviews_count: 1,
      review_ids: [ reviews(:positive).id ],
      summary:
    )

    duplicate = product.insight_batches.build(
      batch_index: 0,
      reviews_count: 1,
      review_ids: [ reviews(:neutral).id ],
      summary:
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:batch_index], "has already been taken"
  end

  private
    def summary
      {
        "pain_points" => [],
        "praised_features" => [],
        "feature_requests" => [],
        "buyer_objections" => [],
        "sentiment_patterns" => [],
        "representative_quotes" => [],
        "supporting_review_ids" => []
      }
    end
end
