require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "has ingestion runs reviews fixtures" do
    product = products(:example)

    assert_includes product.ingestion_runs, ingestion_runs(:pending)
    assert_includes product.reviews, reviews(:positive)
  end

  test "conversation bang creates then reuses one product conversation" do
    product = products(:ready)

    assert_difference -> { product.conversations.count }, 1 do
      product.conversation!
    end

    first_conversation = product.conversations.order(:id).first

    assert_no_difference -> { product.conversations.count } do
      assert_equal first_conversation, product.conversation!
    end
  end

  test "conversation bang does not require configured RubyLLM provider credentials" do
    original_openai_api_key = RubyLLM.config.openai_api_key
    RubyLLM.config.openai_api_key = nil

    assert_predicate products(:ready).conversation!, :persisted?
  ensure
    RubyLLM.config.openai_api_key = original_openai_api_key
  end

  test "conversation does not return stale unsaved record after conversation bang" do
    product = products(:ready)
    built_conversation = product.conversation

    assert_not_predicate built_conversation, :persisted?

    persisted_conversation = product.conversation!

    assert_predicate persisted_conversation, :persisted?
    assert_equal persisted_conversation, product.conversation
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
    assert_includes product.errors[:source_url], "must be Trustpilot URL"
    assert_empty product.errors[:platform]
    assert_empty product.errors[:external_id]
  end

  test "rejects malformed urls without derived identity errors" do
    product = Product.new(source_url: "not url")

    assert_not product.valid?
    assert_includes product.errors[:source_url], "must be valid URL"
    assert_empty product.errors[:platform]
    assert_empty product.errors[:external_id]
  end

  test "derives external id from trustpilot review target" do
    product = Product.new(source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert product.valid?
    assert_equal Product::PLATFORM_TRUSTPILOT, product.platform
    assert_equal "quickbooks.intuit.com", product.external_id
    assert_predicate product, :trustpilot_platform?
  end

  test "finds cached product by trustpilot review target" do
    existing_product = Product.create!(source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com")

    cached_product = Product.find_or_initialize_from_source_url("https://www.trustpilot.com/review/quickbooks.intuit.com?languages=all")

    assert_equal existing_product, cached_product
  end

  test "rejects trustpilot urls without review target" do
    product = Product.new(source_url: "https://www.trustpilot.com/")

    assert_not product.valid?
    assert_includes product.errors[:source_url], "include Trustpilot review target"
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

  test "builds manual import identity without trustpilot validation, source url, or name" do
    product = Product.new(import_mode: Product::PLATFORM_MANUAL_IMPORT)

    assert product.valid?
    assert_predicate product, :manual_import?
    assert_equal Product::PLATFORM_MANUAL_IMPORT, product.platform
    assert_match(/\Amanual-/, product.external_id)
    assert_nil product.source_url
  end

  test "display_name falls back to external id when name is blank" do
    assert_equal "Example", products(:example).display_name

    with_name = Product.new(import_mode: Product::PLATFORM_MANUAL_IMPORT, name: "Manual CRM")
    assert_equal "Manual CRM", with_name.display_name

    # Name is always derived at create time, so external_id only shows if it is somehow cleared.
    without_name = Product.new(import_mode: Product::PLATFORM_MANUAL_IMPORT, name: nil, external_id: "manual-abc")
    assert_equal "manual-abc", without_name.display_name
  end

  test "uses reviews count as usable review count" do
    assert_equal 4, products(:example).usable_review_count
  end

  test "reviews are queryable only after reviews and insight batches exist" do
    product = products(:example)
    product.update!(ingestion_status: "ready", reviews_count: product.reviews.count)

    assert_not_predicate product, :reviews_queryable?
    assert_predicate products(:ready), :reviews_queryable?
  end

  test "reports thin corpus only when ready and below usable review threshold" do
    thin_product = products(:example)

    assert_not_predicate products(:example), :thin_corpus?
    assert_not_predicate products(:ready), :thin_corpus?

    thin_product.ingestion_status = "ready"
    assert_predicate thin_product, :thin_corpus?
  end
end
