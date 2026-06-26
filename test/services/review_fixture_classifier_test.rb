require "test_helper"

class ReviewFixtureClassifierTest < ActiveSupport::TestCase
  test "classifies viable Trustpilot fixture" do
    result = ReviewFixtureClassifier.classify("trustpilot_viable_corpus.html")

    assert File.exist?(result.path)
    assert_equal :viable, result.quality
    assert_equal 20, result.review_count
    assert_not result.blocked
  end

  test "classifies thin Trustpilot fixture" do
    result = ReviewFixtureClassifier.classify("trustpilot_thin_corpus.html")

    assert File.exist?(result.path)
    assert_equal :thin, result.quality
    assert_equal 5, result.review_count
    assert_not result.blocked
  end

  test "classifies blocked Trustpilot fixture" do
    result = ReviewFixtureClassifier.classify("trustpilot_blocked_captcha.html")

    assert File.exist?(result.path)
    assert_equal :blocked, result.quality
    assert_equal 0, result.review_count
    assert result.blocked
  end
end
