require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "has ingestion runs and reviews from fixtures" do
    product = products(:example)

    assert_includes product.ingestion_runs, ingestion_runs(:pending)
    assert_includes product.reviews, reviews(:positive)
  end

  test "requires cache identity fields" do
    product = Product.new(name: "Example")

    assert_not product.valid?
    assert_includes product.errors[:platform], "can't be blank"
    assert_includes product.errors[:source_url], "can't be blank"
    assert_includes product.errors[:external_id], "can't be blank"
  end

  test "enforces one cached product per platform external id pair" do
    existing_product = products(:example)

    duplicate = Product.new(
      platform: existing_product.platform,
      source_url: existing_product.source_url,
      external_id: existing_product.external_id,
      name: "Example Duplicate"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "fixtures can represent pending cached products" do
    assert_predicate products(:manual), :pending?
  end
end
