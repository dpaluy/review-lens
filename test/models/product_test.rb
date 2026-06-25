require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "has ingestion runs and reviews" do
    product = Product.create!(
      platform: "trustpilot",
      source_url: "https://www.trustpilot.com/review/example.com",
      external_id: "example.com",
      name: "Example"
    )

    ingestion_run = product.ingestion_runs.create!(status: "pending")
    review = product.reviews.create!(
      content_hash: "review-hash",
      source_url: product.source_url,
      rating: 5,
      body: "Useful product."
    )

    assert_includes product.ingestion_runs, ingestion_run
    assert_includes product.reviews, review
  end

  test "requires cache identity fields" do
    product = Product.new(name: "Example")

    assert_not product.valid?
    assert_includes product.errors[:platform], "can't be blank"
    assert_includes product.errors[:source_url], "can't be blank"
    assert_includes product.errors[:external_id], "can't be blank"
  end

  test "enforces one cached product per platform external id pair" do
    Product.create!(
      platform: "trustpilot",
      source_url: "https://www.trustpilot.com/review/example.com",
      external_id: "example.com",
      name: "Example"
    )

    duplicate = Product.new(
      platform: "trustpilot",
      source_url: "https://www.trustpilot.com/review/example.com",
      external_id: "example.com",
      name: "Example Duplicate"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "defaults ingestion status to pending" do
    product = Product.create!(
      platform: "manual",
      source_url: "https://example.com/reviews",
      external_id: "manual-example",
      name: "Manual Example"
    )

    assert_predicate product, :pending?
  end
end
