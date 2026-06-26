require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "has ingestion runs reviews fixtures" do
    product = products(:example)

    assert_includes product.ingestion_runs, ingestion_runs(:pending)
    assert_includes product.reviews, reviews(:positive)
  end

  test "requires source url before deriving cache identity" do
    product = Product.new(name: "Example")

    assert_not product.valid?
    assert_includes product.errors[:source_url], "can't be blank"
    assert_empty product.errors[:platform]
    assert_empty product.errors[:external_id]
  end

  test "rejects unsupported urls without derived identity errors" do
    product = Product.new(source_url: "https://www.getapp.com/customer-management-software/a/hubspot-crm/")

    assert_not product.valid?
    assert_includes product.errors[:source_url], "must be a Trustpilot URL"
    assert_empty product.errors[:platform]
    assert_empty product.errors[:external_id]
  end

  test "rejects malformed urls without derived identity errors" do
    product = Product.new(source_url: "not url")

    assert_not product.valid?
    assert_includes product.errors[:source_url], "must be a valid URL"
    assert_empty product.errors[:platform]
    assert_empty product.errors[:external_id]
  end

  test "derives external id from trustpilot review target" do
    product = Product.new(source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert product.valid?
    assert_equal "trustpilot", product.platform
    assert_equal "quickbooks.intuit.com", product.external_id
  end

  test "finds cached product by trustpilot review target" do
    existing_product = Product.create!(source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com")

    cached_product = Product.find_or_initialize_from_source_url("https://www.trustpilot.com/review/quickbooks.intuit.com?languages=all")

    assert_predicate cached_product, :persisted?
    assert_equal existing_product, cached_product
  end

  test "rejects trustpilot urls without review target" do
    product = Product.new(source_url: "https://www.trustpilot.com/review/")

    assert_not product.valid?
    assert_includes product.errors[:source_url], "must include a Trustpilot review target"
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
