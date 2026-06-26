require "test_helper"
require Rails.root.join("script/scrape_probe_cli")
require "stringio"

class Script::ScrapeProbeCliTest < ActiveSupport::TestCase
  test "formats PRD probe fields from local fixture without fetching" do
    fetcher = RecordingFetcher.new
    output = StringIO.new

    exit_status = Script::ScrapeProbeCli.new(fetcher: fetcher, output: output).call(
      [ "--fixture", "test/fixtures/files/trustpilot_probe_sample.html" ]
    )

    assert_equal 0, exit_status
    report = JSON.parse(output.string)
    assert_equal "fixture", report.fetch("input_mode")
    assert_equal "ok", report.fetch("status")
    assert_nil report["http_status"]
    assert report.fetch("html_bytes").positive?
    assert_equal true, report.fetch("title_detected")
    assert_equal "Intuit QuickBooks Reviews | Trustpilot", report.fetch("title")
    assert_equal true, report.fetch("trust_score_detected")
    assert_equal "3.9", report.fetch("trust_score")
    assert_equal true, report.fetch("rating_distribution_detected")
    assert_equal true, report.fetch("review_count_detected")
    assert_equal 16_788, report.fetch("review_count")
    assert_equal 50, report.fetch("usable_raw_review_body_count")
    assert_equal true, report.fetch("trustpilot_ai_summary_detected")
    assert_equal false, report.fetch("captcha_block_detected")
    assert_equal "strong", report.fetch("corpus_quality")
    assert_equal "trustpilot", report.fetch("recommended_adapter")

    assert_empty fetcher.requested_urls
  end

  test "reports missing fixture as offline failure without fetching" do
    fetcher = RecordingFetcher.new
    output = StringIO.new

    exit_status = Script::ScrapeProbeCli.new(fetcher: fetcher, output: output).call(
      [ "--fixture", "test/fixtures/files/missing_trustpilot.html" ]
    )

    assert_equal 1, exit_status
    report = JSON.parse(output.string)
    assert_equal "fixture_missing", report.fetch("status")
    assert_equal "fixture_missing", report.fetch("error_code")
    assert_equal "fail", report.fetch("corpus_quality")
    assert_equal "manual_import", report.fetch("recommended_adapter")

    assert_empty fetcher.requested_urls
  end

  test "saves fetched html to requested fixture path" do
    html = file_fixture("trustpilot_viable_corpus.html").read
    fetcher = RecordingFetcher.new(
      Ingestion::Fetcher::Result.new(
        successful: true,
        body: html,
        metadata: { http_status: 200, html_bytes: html.bytesize }
      )
    )
    output = StringIO.new
    fixture_path = Rails.root.join("tmp/scrape_probe_cli_fixture.html")

    FileUtils.rm_f(fixture_path)

    exit_status = Script::ScrapeProbeCli.new(fetcher: fetcher, output: output).call(
      [
        "https://www.trustpilot.com/review/example.com",
        "--save-fixture",
        fixture_path.to_s
      ]
    )

    assert_equal 0, exit_status
    assert_equal html, File.read(fixture_path)
    report = JSON.parse(output.string)
    assert_equal 200, report.fetch("http_status")
    assert_equal fixture_path.to_s, report.fetch("saved_fixture")

    assert_equal [ "https://www.trustpilot.com/review/example.com" ], fetcher.requested_urls
  ensure
    FileUtils.rm_f(fixture_path) if fixture_path
  end

  class RecordingFetcher
    attr_reader :requested_urls

    def initialize(result = nil)
      @result = result
      @requested_urls = []
    end

    def fetch(url)
      @requested_urls << url
      @result
    end
  end
end
