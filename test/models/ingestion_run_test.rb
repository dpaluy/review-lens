require "test_helper"

class IngestionRunTest < ActiveSupport::TestCase
  test "belongs to product and defaults status" do
    product = Product.create!(
      platform: "trustpilot",
      source_url: "https://www.trustpilot.com/review/example.com",
      external_id: "example.com",
      name: "Example"
    )

    ingestion_run = product.ingestion_runs.create!

    assert_equal product, ingestion_run.product
    assert_predicate ingestion_run, :pending?
  end
end
