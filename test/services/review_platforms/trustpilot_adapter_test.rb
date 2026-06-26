require "test_helper"

class ReviewPlatforms::TrustpilotAdapterTest < ActiveSupport::TestCase
  test "parses raw Trustpilot review cards into normalized review hashes" do
    reviews = adapter.parse_reviews(fixture_html, source_url:)

    assert_equal 2, reviews.length

    first_review = reviews.first
    assert_equal "review-1", first_review[:external_review_id]
    assert_equal "https://www.trustpilot.com/reviews/review-1", first_review[:source_url]
    assert_equal 5, first_review[:rating]
    assert_equal "Fast setup", first_review[:title]
    assert_equal "Setup was fast and the bank sync saved us hours every week.", first_review[:body]
    assert_equal "Jane Analyst", first_review[:reviewer_label]
    assert_equal Time.zone.parse("2026-06-01T12:00:00Z"), first_review[:review_date]
    assert first_review[:content_hash].present?
    assert_equal "trustpilot-html-v1", first_review[:raw_payload][:parser]
  end

  test "does not parse Trustpilot AI summary text as a review" do
    review_bodies = adapter.parse_reviews(fixture_html, source_url:).pluck(:body)

    assert_not_includes review_bodies, "Reviewers say QuickBooks has support and billing concerns."
  end

  test "parses product metadata" do
    metadata = adapter.parse_product_metadata(file_fixture("trustpilot_viable_corpus.html").read)

    assert_equal "LedgerFlow", metadata[:name]
  end

  private
    def adapter
      ReviewPlatforms::TrustpilotAdapter.new
    end

    def fixture_html
      file_fixture("trustpilot_quickbooks.html").read
    end

    def source_url
      "https://www.trustpilot.com/review/quickbooks.intuit.com"
    end
end
