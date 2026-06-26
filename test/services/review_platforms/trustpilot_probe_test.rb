require "test_helper"

class ReviewPlatforms::TrustpilotProbeTest < ActiveSupport::TestCase
  test "classifies strong corpus raw user review bodies" do
    html = file_fixture("trustpilot_probe_sample.html").read

    result = ReviewPlatforms::TrustpilotProbe.new(
      html:,
      source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com",
      fetch_metadata: { final_url: "https://www.trustpilot.com/review/quickbooks.intuit.com" }
    ).call

    assert_equal "ok", result[:status]
    assert_equal "Intuit QuickBooks Reviews | Trustpilot", result[:title]
    assert_equal "3.9", result[:trust_score]
    assert_equal 16_788, result[:review_count]
    assert result[:rating_distribution_detected]
    assert result[:trustpilot_ai_summary_detected]
    assert_not result[:captcha_or_block_detected]
    assert_equal 50, result[:usable_raw_review_count]
    assert_equal 20, result[:minimum_usable_reviews]
    assert_equal 50, result[:strong_usable_reviews]
    assert_equal "strong", result[:corpus_quality]
    assert_equal "trustpilot", result[:recommended_adapter]
    assert_equal "https://www.trustpilot.com/review/quickbooks.intuit.com", result[:fetch_metadata][:final_url]
  end

  test "classifies twenty user review bodies viable" do
    html = trustpilot_html(review_count: 20)

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: source_url).call

    assert_equal 20, result[:usable_raw_review_count]
    assert_equal "viable", result[:corpus_quality]
    assert_equal "trustpilot", result[:recommended_adapter]
  end

  test "classifies fewer than twenty user review bodies thin" do
    html = trustpilot_html(review_count: 19)

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: source_url).call

    assert_equal 19, result[:usable_raw_review_count]
    assert_equal "thin", result[:corpus_quality]
    assert_equal "manual_import", result[:recommended_adapter]
  end

  test "classifies captcha or blocked page as fail" do
    html = "<html><head><title>Security check</title></head><body>Please complete CAPTCHA continue.</body></html>"

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: source_url).call

    assert_equal "blocked", result[:status]
    assert result[:captcha_or_block_detected]
    assert_equal "fail", result[:corpus_quality]
    assert_equal "manual_import", result[:recommended_adapter]
  end

  test "does not count trustpilot ai summary as usable raw review" do
    html = <<~HTML
      <html>
        <body>
          <section>
            <h2>AI-generated summary</h2>
            <p data-service-review-text-typography="true">
              Trustpilot AI-generated summary says customers mention billing and onboarding often.
            </p>
          </section>
        </body>
      </html>
    HTML

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: source_url).call

    assert result[:trustpilot_ai_summary_detected]
    assert_equal 0, result[:usable_raw_review_count]
    assert_equal "fail", result[:corpus_quality]
    assert_equal "manual_import", result[:recommended_adapter]
  end

  test "extracts nested json ld aggregate rating metadata" do
    html = <<~HTML
      <html>
        <head>
          <title>Nested Trustpilot Page</title>
          <script type="application/ld+json">
            {"@graph":[{"aggregateRating":{"ratingValue":"4.2","reviewCount":"1,234"}}]}
          </script>
        </head>
        <body>#{review_cards(20)}</body>
      </html>
    HTML

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: source_url).call

    assert_equal "4.2", result[:trust_score]
    assert_equal 1_234, result[:review_count]
    assert result[:trust_score_detected]
    assert result[:review_count_detected]
  end

  private

  def source_url
    "https://www.trustpilot.com/review/quickbooks.intuit.com"
  end

  def trustpilot_html(review_count:)
    <<~HTML
      <html>
        <head>
          <title>Intuit QuickBooks Reviews | Trustpilot</title>
          <script type="application/ld+json">
            {"@type":"Organization","aggregateRating":{"ratingValue":"3.9","reviewCount":"16,788"}}
          </script>
        </head>
        <body>
          <p>TrustScore 3.9</p>
          <section aria-label="Rating distribution">
            <span>5-star</span><span>4-star</span><span>3-star</span><span>2-star</span><span>1-star</span>
          </section>
          <section>
            <h2>AI-generated summary</h2>
            <p>Trustpilot AI-created summary reviews.</p>
          </section>
          #{review_cards(review_count)}
        </body>
      </html>
    HTML
  end

  def review_cards(count)
    count.times.map do |index|
      <<~HTML
        <article data-service-review-card-paper="true">
          <h2>Review title #{index}</h2>
          <p data-service-review-text-typography="true">
            This real customer written review body #{index} has enough words to be useful for grounded analysis.
          </p>
        </article>
      HTML
    end.join
  end
end
