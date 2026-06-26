require "test_helper"

class ReviewAnalysis::ContextBuilderTest < ActiveSupport::TestCase
  test "builds context from product summary insight batches and matching current product reviews" do
    product = products(:ready)
    product.update!(
      ingestion_summary: { "warnings" => [ "One duplicate review was skipped" ] },
      rating_distribution: { "2" => 1, "3" => 1, "4" => 1 },
      sentiment_distribution: { "negative" => 1, "neutral" => 1, "positive" => 1 }
    )

    context = ReviewAnalysis::ContextBuilder.new(
      product:,
      question: "What billing support problems appear?",
      review_limit: 50
    ).call

    assert_equal product.id, context.data.fetch(:product).fetch(:id)
    assert_equal 1, context.data.fetch(:insight_batches).size
    assert_equal [ reviews(:ready_billing).id ], context.data.fetch(:reviews).map { |review| review.fetch(:id) }
    assert_includes context.text, "One duplicate review was skipped"
    assert_includes context.text, "Billing support took three weeks"
    assert_not_includes context.text, reviews(:negative).body
  end

  test "caps review context at configured limit" do
    context = ReviewAnalysis::ContextBuilder.new(
      product: products(:ready),
      question: "reviews",
      review_limit: 2
    ).call

    assert_equal 2, context.data.fetch(:reviews).size
  end
end
