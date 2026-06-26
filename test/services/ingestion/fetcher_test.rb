require "test_helper"

class Ingestion::FetcherTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :headers, :body, keyword_init: true)

  test "fetches whitelisted trustpilot url and records metadata" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 200, headers: { "content-type" => "text/html" }, body: "<html>ok</html>")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_predicate result, :success?
    assert_equal "<html>ok</html>", result.body
    assert_equal 15, result.metadata[:html_bytes]
    assert_equal 1, result.metadata[:pages_attempted]
    assert_equal 1, result.metadata[:pages_succeeded]
  end

  test "rejects non trustpilot hosts before requesting" do
    requested = false
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      requested = true
      Response.new(status: 200, headers: {}, body: "should not happen")
    })

    result = fetcher.fetch("https://example.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "unsupported_host", result.error_code
    assert_not requested
  end

  test "follows at most two redirects" do
    responses = [
      Response.new(status: 302, headers: { "location" => "https://www.trustpilot.com/review/quickbooks.intuit.com?languages=all" }, body: ""),
      Response.new(status: 301, headers: { "location" => "https://www.trustpilot.com/review/quickbooks.intuit.com?sort=recency" }, body: ""),
      Response.new(status: 302, headers: { "location" => "https://www.trustpilot.com/review/quickbooks.intuit.com?stars=1" }, body: "")
    ]
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits| responses.shift })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "too_many_redirects", result.error_code
    assert_equal 3, result.metadata[:pages_attempted]
  end

  test "rejects redirect to non whitelisted host" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 302, headers: { "location" => "https://evil.example/review/quickbooks.intuit.com" }, body: "")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "redirect_host_not_allowed", result.error_code
  end

  test "reports timeout as fetch failure" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits| raise Timeout::Error })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "timeout", result.error_code
    assert_equal 10, result.metadata[:timeout_seconds]
  end

  test "rejects responses larger than five megabytes" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 200, headers: {}, body: "a" * (5.megabytes + 1))
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "response_too_large", result.error_code
    assert_equal 5.megabytes, result.metadata[:max_bytes]
  end
end
