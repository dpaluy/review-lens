require "test_helper"

class ReviewAnalysis::BatchSummarizerTest < ActiveSupport::TestCase
  test "creates insight batches in deterministic review order" do
    product = products(:example)
    client = FakeBatchSummaryClient.new

    result = ReviewAnalysis::BatchSummarizer.new(product:, batch_size: 2, client:).call

    assert_equal 2, result.batches_count
    assert_equal 4, result.reviews_count
    assert_equal 2, product.insight_batches.count

    first_batch = product.insight_batches.order(:batch_index).first
    assert_equal 0, first_batch.batch_index
    assert_equal 2, first_batch.reviews_count
    assert_equal product.reviews.order(:id).limit(2).pluck(:id), first_batch.review_ids
    assert_equal first_batch.review_ids.map(&:to_s), client.calls.first.map { |review| review[:review_id] }
    assert_equal first_batch.review_ids.map(&:to_s), first_batch.summary["supporting_review_ids"]
  end

  test "replaces existing insight batches" do
    product = products(:example)
    product.insight_batches.create!(
      batch_index: 99,
      reviews_count: 1,
      review_ids: [ reviews(:positive).id ],
      summary: { "stale" => true }
    )

    ReviewAnalysis::BatchSummarizer.new(
      product:,
      batch_size: 3,
      client: FakeBatchSummaryClient.new
    ).call

    assert_equal [ 0, 1 ], product.insight_batches.order(:batch_index).pluck(:batch_index)
    assert_empty product.insight_batches.where("summary ? 'stale'")
  end

  test "does not call client when product has no reviews" do
    product = products(:manual)
    client = FakeBatchSummaryClient.new

    result = ReviewAnalysis::BatchSummarizer.new(product:, client:).call

    assert_equal 0, result.batches_count
    assert_equal 0, result.reviews_count
    assert_empty client.calls
    assert_empty product.insight_batches
  end

  private
    class FakeBatchSummaryClient
      attr_reader :calls

      def initialize
        @calls = []
      end

      def summarize(reviews:)
        calls << reviews

        {
          "pain_points" => [ theme("Slow onboarding", reviews) ],
          "praised_features" => [ theme("Helpful support", reviews) ],
          "feature_requests" => [ theme("Better exports", reviews) ],
          "buyer_objections" => [ theme("Price feels high", reviews) ],
          "sentiment_patterns" => [ theme("Negative reviews mention billing", reviews) ],
          "representative_quotes" => [
            {
              "review_id" => reviews.first[:review_id],
              "quote" => reviews.first[:body],
              "theme" => "billing"
            }
          ],
          "supporting_review_ids" => reviews.map { |review| review[:review_id] }
        }
      end

      private
        def theme(name, reviews)
          {
            "theme" => name,
            "summary" => "#{name} appears in this batch",
            "supporting_review_ids" => reviews.map { |review| review[:review_id] }
          }
        end
    end
end
