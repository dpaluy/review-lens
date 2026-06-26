require "test_helper"

class ReviewPlatforms::TrustpilotProbeTest < ActiveSupport::TestCase
  test "classifies strong corpus from raw user review bodies" do
    html = file_fixture("trustpilot_probe_sample.html").read

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com").call

    assert_equal "ok", result[:status]
    assert_equal "Intuit QuickBooks Reviews | Trustpilot", result[:title]
    assert_equal "3.9", result[:trust_score]
    assert_equal 16_788, result[:review_count]
    assert result[:rating_distribution_detected]
    assert result[:trustpilot_ai_summary_detected]
    assert_not result[:captcha_or_block_detected]
    assert_equal 50, result[:usable_raw_review_count]
    assert_equal "strong", result[:corpus_quality]
    assert_equal "trustpilot", result[:recommended_adapter]
  end

  test "classifies fewer than twenty user review bodies as thin" do
    html = trustpilot_html(review_count: 19)

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com").call

    assert_equal 19, result[:usable_raw_review_count]
    assert_equal "thin", result[:corpus_quality]
    assert_equal "manual_import", result[:recommended_adapter]
  end

  test "classifies captcha or blocked page as fail" do
    html = "<html><head><title>Security check</title></head><body>Please complete the CAPTCHA to continue.</body></html>"

    result = ReviewPlatforms::TrustpilotProbe.new(html:, source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com").call

    assert result[:captcha_or_block_detected]
    assert_equal "fail", result[:corpus_quality]
    assert_equal "manual_import", result[:recommended_adapter]
  end

  private
    def trustpilot_html(review_count:)
      reviews = review_count.times.map do |index|
        <<~HTML
          <article data-service-review-card-paper="true">
            <h2>Review title #{index}</h2>
            <p data-service-review-text-typography="true">This is a real customer written review body #{index} with enough words to be useful for grounded analysis.</p>
          </article>
        HTML
      end.join

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
              <p>Trustpilot AI-created summary of reviews.</p>
            </section>
            #{reviews}
          </body>
        </html>
      HTML
    end
end
