require "test_helper"

class Ingestion::ImporterTest < ActiveSupport::TestCase
  test "imports parsed reviews for current product and derives sentiment from rating" do
    product = products(:manual)

    result = Ingestion::Importer.import(product, [
      parsed_review(external_review_id: "import-positive", rating: 5),
      parsed_review(external_review_id: "import-neutral", rating: 3, body: "It was okay."),
      parsed_review(external_review_id: "import-negative", rating: 1, body: "Billing failed.")
    ])

    assert_equal 3, result.imported
    assert_equal 0, result.skipped
    assert_equal %w[ negative neutral positive ], product.reviews.order(:sentiment).pluck(:sentiment)
  end

  test "skips duplicate external review ids and empty bodies" do
    product = products(:manual)
    duplicate = parsed_review(external_review_id: "same-review", body: "Original body")

    result = Ingestion::Importer.import(product, [
      duplicate,
      parsed_review(external_review_id: "same-review", body: "Changed body"),
      parsed_review(external_review_id: "blank-review", body: " ")
    ])

    assert_equal 1, result.imported
    assert_equal 2, result.skipped
    assert_equal [ "Original body" ], product.reviews.pluck(:body)
  end

  test "deduplicates by content hash when external review id is missing" do
    product = products(:manual)

    result = Ingestion::Importer.import(product, [
      parsed_review(external_review_id: nil, content_hash: "same-content", body: "Same body"),
      parsed_review(external_review_id: nil, content_hash: "same-content", body: "Same body")
    ])

    assert_equal 1, result.imported
    assert_equal 1, result.skipped
    assert_equal 1, product.reviews.count
  end

  test "truncates review body and marks corpus quality thin below twenty usable reviews" do
    product = products(:manual)

    Ingestion::Importer.import(product, [
      parsed_review(external_review_id: "long-review", body: "a" * 5_050)
    ])

    review = product.reviews.find_by!(external_review_id: "long-review")
    assert_equal 5_000, review.body.length
    assert_equal "thin", product.reload.ingestion_summary["corpus_quality"]
    assert_equal 1, product.ingestion_summary["usable_review_count"]
  end

  private
    def parsed_review(attributes = {})
      {
        external_review_id: "imported-review",
        content_hash: SecureRandom.hex(16),
        source_url: "https://www.trustpilot.com/review/example.com",
        rating: 4,
        title: "Useful",
        body: "Useful review body.",
        reviewer_label: "Reviewer",
        review_date: Time.zone.parse("2026-06-01T12:00:00Z"),
        raw_payload: { "source" => "fixture" }
      }.merge(attributes)
    end
end
