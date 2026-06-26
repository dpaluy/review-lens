require "test_helper"

class Ingestion::SummaryBuilderTest < ActiveSupport::TestCase
  test "computes deterministic aggregate summary without LLM" do
    reviews(:positive).update!(
      review_date: Time.zone.parse("2026-05-01T12:00:00Z"),
      reviewer_label: "Jane Analyst",
      reviewer_role: "Admin",
      reviewer_company_size: "51-200",
      title: "Works well"
    )
    reviews(:neutral).update!(
      review_date: Time.zone.parse("2026-06-01T12:00:00Z"),
      reviewer_label: "Sam Operator",
      title: "Fine"
    )
    reviews(:negative).update!(reviewer_label: "Pat Buyer")

    product = products(:example)

    Ingestion::SummaryBuilder.new(product:).call

    product.reload
    assert_equal 4, product.reviews_count
    assert_equal 3.0, product.average_rating.to_f
    assert_equal({ "2.0" => 1, "3.0" => 1, "4.0" => 1 }, product.rating_distribution)
    assert_equal({ "negative" => 1, "neutral" => 1, "positive" => 1, "unknown" => 1 }, product.sentiment_distribution)
    assert_equal Time.zone.parse("2026-05-01T12:00:00Z"), product.oldest_review_at
    assert_equal Time.zone.parse("2026-06-01T12:00:00Z"), product.newest_review_at

    summary = product.ingestion_summary
    assert_equal 4, summary["reviews_imported"]
    assert_equal 4, summary["usable_review_count"]
    assert_equal "thin", summary["corpus_quality"]
    assert_equal product.platform, summary["source_platform"]
    assert_equal product.source_url, summary["source_url"]
    assert_equal({ "present" => 4, "total" => 4, "percentage" => 100 }, summary.dig("field_coverage", "body"))
    assert_equal({ "present" => 3, "total" => 4, "percentage" => 75 }, summary.dig("field_coverage", "rating"))
    assert_equal({ "present" => 2, "total" => 4, "percentage" => 50 }, summary.dig("field_coverage", "review_date"))
    assert_equal({ "present" => 3, "total" => 4, "percentage" => 75 }, summary.dig("field_coverage", "reviewer_label"))
    assert_equal({ "present" => 1, "total" => 4, "percentage" => 25 }, summary.dig("field_coverage", "reviewer_role"))
    assert_equal({ "present" => 1, "total" => 4, "percentage" => 25 }, summary.dig("field_coverage", "reviewer_company_size"))
    assert_equal({ "present" => 2, "total" => 4, "percentage" => 50 }, summary.dig("field_coverage", "title"))
  end
end
