require "test_helper"

class Ingestion::FetcherTest < ActiveSupport::TestCase
  Response = Struct.new(:status, :headers, :body, keyword_init: true)

  test "fetches whitelisted trustpilot url records metadata" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, limits|
      assert_equal 10, limits[:timeout_seconds]
      assert_equal 5.megabytes, limits[:max_bytes]

      Response.new(status: 200, headers: { "content-type" => "text/html" }, body: "<html>ok</html>")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_predicate result, :success?
    assert_equal "<html>ok</html>", result.body
    assert_equal 15, result.metadata[:html_bytes]
    assert_equal 1, result.metadata[:pages_attempted]
    assert_equal 1, result.metadata[:pages_succeeded]
    assert_equal 0, result.metadata[:redirect_count]
    assert_equal 200, result.metadata[:http_status]
    assert_equal "text/html", result.metadata[:content_type]
  end

  test "retains block page body for blocked http responses" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 403, headers: { "content-type" => "text/html" }, body: "<html>blocked</html>")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "blocked", result.error_code
    assert_equal "<html>blocked</html>", result.body
    assert_equal 20, result.metadata[:html_bytes]
    assert_equal 403, result.metadata[:http_status]
    assert_equal 1, result.metadata[:pages_attempted]
    assert_equal 0, result.metadata[:pages_succeeded]
  end

  test "retains block page body for rate limited responses" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 429, headers: {}, body: "<html>slow down</html>")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "blocked", result.error_code
    assert_equal "<html>slow down</html>", result.body
    assert_equal 429, result.metadata[:http_status]
  end

  test "fails server error http responses before parsing" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 500, headers: {}, body: "<html>server error</html>")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "http_500", result.error_code
    assert_nil result.body
    assert_equal 500, result.metadata[:http_status]
    assert_equal 1, result.metadata[:pages_attempted]
    assert_equal 0, result.metadata[:pages_succeeded]
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

  test "rejects invalid url before requesting" do
    requested = false
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      requested = true
      Response.new(status: 200, headers: {}, body: "should not happen")
    })

    result = fetcher.fetch("not a url")

    assert_not result.success?
    assert_equal "invalid_url", result.error_code
    assert_not requested
  end

  test "follows at most two trustpilot redirects" do
    responses = [
      Response.new(status: 302, headers: { "location" => "https://www.trustpilot.com/review/quickbooks.intuit.com?languages=all" }, body: ""),
      Response.new(status: 301, headers: { "location" => "https://trustpilot.com/review/quickbooks.intuit.com?sort=recency" }, body: ""),
      Response.new(status: 200, headers: {}, body: "<html>redirected</html>")
    ]
    requested_urls = []
    fetcher = Ingestion::Fetcher.new(transport: lambda { |uri, _limits|
      requested_urls << uri.to_s
      responses.shift
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_predicate result, :success?
    assert_equal "<html>redirected</html>", result.body
    assert_equal 3, result.metadata[:pages_attempted]
    assert_equal 2, result.metadata[:redirect_count]
    assert_equal [
      "https://www.trustpilot.com/review/quickbooks.intuit.com",
      "https://www.trustpilot.com/review/quickbooks.intuit.com?languages=all",
      "https://trustpilot.com/review/quickbooks.intuit.com?sort=recency"
    ], requested_urls
  end

  test "fails when redirect count exceeds two" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 302, headers: { "location" => "/review/quickbooks.intuit.com" }, body: "")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "too_many_redirects", result.error_code
    assert_equal 3, result.metadata[:pages_attempted]
    assert_equal 3, result.metadata[:redirect_count]
  end

  test "fails when redirect leaves trustpilot whitelist" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits|
      Response.new(status: 302, headers: { "location" => "https://evil.example/review/quickbooks.intuit.com" }, body: "")
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "redirect_host_not_allowed", result.error_code
    assert_equal "https://evil.example/review/quickbooks.intuit.com", result.metadata[:final_url]
  end

  test "fails when response exceeds five megabytes" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, limits|
      Response.new(status: 200, headers: {}, body: "x" * (limits[:max_bytes] + 1))
    })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "response_too_large", result.error_code
    assert_equal 5.megabytes, result.metadata[:max_bytes]
    assert_equal 5.megabytes + 1, result.metadata[:html_bytes]
  end

  test "maps timeout transport errors" do
    fetcher = Ingestion::Fetcher.new(transport: lambda { |_uri, _limits| raise Timeout::Error })

    result = fetcher.fetch("https://www.trustpilot.com/review/quickbooks.intuit.com")

    assert_not result.success?
    assert_equal "timeout", result.error_code
    assert_equal 1, result.metadata[:pages_attempted]
  end
end
