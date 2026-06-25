require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  setup do
    @product = Product.create!(
      platform: "trustpilot",
      source_url: "https://www.trustpilot.com/review/example.com",
      external_id: "example.com",
      name: "Example"
    )
  end

  test "belongs to product" do
    review = @product.reviews.create!(
      content_hash: "review-hash",
      source_url: @product.source_url,
      rating: 4,
      body: "Works well."
    )

    assert_equal @product, review.product
  end

  test "derives sentiment from rating" do
    assert_equal "positive", @product.reviews.create!(content_hash: "positive", source_url: @product.source_url, rating: 4, body: "Good").sentiment
    assert_equal "neutral", @product.reviews.create!(content_hash: "neutral", source_url: @product.source_url, rating: 3, body: "Fine").sentiment
    assert_equal "negative", @product.reviews.create!(content_hash: "negative", source_url: @product.source_url, rating: 2, body: "Bad").sentiment
    assert_equal "unknown", @product.reviews.create!(content_hash: "unknown", source_url: @product.source_url, body: "No rating").sentiment
  end

  test "requires a body" do
    review = @product.reviews.build(content_hash: "empty", source_url: @product.source_url)

    assert_not review.valid?
    assert_includes review.errors[:body], "can't be blank"
  end

  test "enforces unique content hash per product" do
    @product.reviews.create!(
      content_hash: "same-hash",
      source_url: @product.source_url,
      body: "First"
    )

    duplicate = @product.reviews.build(
      content_hash: "same-hash",
      source_url: @product.source_url,
      body: "Second"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:content_hash], "has already been taken"
  end

  test "normalizes blank external review ids so content hash remains fallback dedupe key" do
    first = @product.reviews.create!(
      external_review_id: "",
      content_hash: "first-hash",
      source_url: @product.source_url,
      body: "First"
    )
    second = @product.reviews.create!(
      external_review_id: "",
      content_hash: "second-hash",
      source_url: @product.source_url,
      body: "Second"
    )

    assert_nil first.external_review_id
    assert_nil second.external_review_id
  end
end
