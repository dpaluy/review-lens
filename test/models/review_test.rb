require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    @product = products(:example)
  end

  test "belongs to product from fixture" do
    assert_equal @product, reviews(:positive).product
  end

  test "derives sentiment from rating" do
    assert_equal "positive", build_review(rating: 4).tap(&:valid?).sentiment
    assert_equal "neutral", build_review(rating: 3).tap(&:valid?).sentiment
    assert_equal "negative", build_review(rating: 2).tap(&:valid?).sentiment
    assert_equal "unknown", build_review(rating: nil).tap(&:valid?).sentiment
  end

  test "requires a body" do
    review = @product.reviews.build(content_hash: "empty", source_url: @product.source_url)

    assert_not review.valid?
    assert_includes review.errors[:body], "can't be blank"
  end

  test "enforces unique content hash per product" do
    duplicate = @product.reviews.build(
      content_hash: reviews(:positive).content_hash,
      source_url: @product.source_url,
      body: "Second"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:content_hash], "has already been taken"
  end

  test "normalizes blank external review ids so content hash remains fallback dedupe key" do
    review = build_review(
      external_review_id: "",
      content_hash: "blank-external-id"
    )
    review.valid?

    assert_nil review.external_review_id
  end

  private

  def build_review(attributes = {})
    @product.reviews.build({
      content_hash: "new-review-hash",
      source_url: @product.source_url,
      body: "Review body"
    }.merge(attributes))
  end
end
