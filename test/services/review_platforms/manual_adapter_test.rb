require "test_helper"

module ReviewPlatforms
  class ManualAdapterTest < ActiveSupport::TestCase
    test "parses pasted CSV reviews" do
      csv = <<~CSV
        title,body,rating,reviewer,date,reviewer_role,company_size,external_review_id
        Easy setup,"Setup took one afternoon and support answered quickly.",5,Alex,2026-01-10,Operations lead,51-200,manual-1
        Billing friction,"The cancellation flow was confusing and billing took days to respond.",2,Sam,2026-01-11,Controller,11-50,manual-2
      CSV

      reviews = ManualAdapter.new(source_url: "https://example.com/reviews").parse_reviews(csv)

      assert_equal 2, reviews.size
      assert_equal "manual-1", reviews.first[:external_review_id]
      assert_equal "Easy setup", reviews.first[:title]
      assert_equal "Setup took one afternoon and support answered quickly.", reviews.first[:body]
      assert_equal BigDecimal("5"), reviews.first[:rating]
      assert_equal "Alex", reviews.first[:reviewer_label]
      assert_equal Date.new(2026, 1, 10), reviews.first[:review_date]
      assert_equal "manual_csv", reviews.first[:raw_payload].fetch(:import_mode)
    end

    test "falls back to blank-line-separated review blocks" do
      reviews = ManualAdapter.new(source_url: "https://example.com/reviews").parse_reviews(<<~TEXT)
        Setup was simple.

        Billing was confusing.
      TEXT

      assert_equal 2, reviews.size
      assert_equal "Setup was simple.", reviews.first[:body]
      assert_equal "manual", reviews.first[:raw_payload].fetch(:import_mode)
    end
  end
end
