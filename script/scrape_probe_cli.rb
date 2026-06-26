require "json"
require "optparse"

module Script
  class ScrapeProbeCli
    DEFAULT_URL = "https://www.trustpilot.com/review/quickbooks.intuit.com"
    DEFAULT_FIXTURE_PATH = Rails.root.join("test/fixtures/files/trustpilot_quickbooks.html")

    def initialize(fetcher: Ingestion::Fetcher.new, probe_class: ReviewPlatforms::TrustpilotProbe, output: $stdout)
      @fetcher = fetcher
      @probe_class = probe_class
      @output = output
    end

    def call(argv)
      options = parse_options(argv)
      source_url = argv.first || DEFAULT_URL
      result = options[:fixture_path] ? probe_fixture(options[:fixture_path], source_url) : probe_live(source_url, options)

      @output.puts(JSON.pretty_generate(result[:report]))
      result[:exit_status]
    end

    private

    def parse_options(argv)
      options = {
        save_fixture: false,
        save_fixture_path: DEFAULT_FIXTURE_PATH
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: script/scrape_probe.rb [URL] [--fixture PATH] [--save-fixture [PATH]]"
        opts.separator ""
        opts.separator "Examples:"
        opts.separator "  script/scrape_probe.rb --fixture test/fixtures/files/trustpilot_quickbooks.html"
        opts.separator "  script/scrape_probe.rb https://www.trustpilot.com/review/quickbooks.intuit.com --save-fixture"

        opts.on("--fixture PATH", "Probe an existing local HTML fixture without network access") do |path|
          options[:fixture_path] = expand_path(path)
        end

        opts.on("--save-fixture [PATH]", "Save fetched HTML to PATH, default: #{DEFAULT_FIXTURE_PATH}") do |path|
          options[:save_fixture] = true
          options[:save_fixture_path] = expand_path(path) if path.present?
        end
      end

      parser.parse!(argv)
      options
    end

    def probe_fixture(fixture_path, source_url)
      html = File.read(fixture_path)
      metadata = {
        input_mode: "fixture",
        fixture_path: fixture_path,
        html_bytes: html.bytesize
      }

      report = report_for(html: html, source_url: source_url, fetch_metadata: metadata).merge(input_mode: "fixture")
      { report: report, exit_status: exit_status_for(report) }
    rescue Errno::ENOENT
      report = failure_report(
        source_url: source_url,
        status: "fixture_missing",
        error_code: "fixture_missing",
        fetch_metadata: { input_mode: "fixture", fixture_path: fixture_path }
      )
      { report: report, exit_status: 1 }
    end

    def probe_live(source_url, options)
      fetch_result = @fetcher.fetch(source_url)

      unless fetch_result.success?
        report = failure_report(
          source_url: source_url,
          status: "fetch_failed",
          error_code: fetch_result.error_code,
          fetch_metadata: fetch_result.metadata
        )
        return { report: report, exit_status: 1 }
      end

      report = report_for(html: fetch_result.body, source_url: source_url, fetch_metadata: fetch_result.metadata)

      if options[:save_fixture]
        File.write(options[:save_fixture_path], fetch_result.body)
        report[:saved_fixture] = options[:save_fixture_path].to_s
      end

      { report: report, exit_status: exit_status_for(report) }
    end

    def report_for(html:, source_url:, fetch_metadata:)
      probe_result = @probe_class.new(html: html, source_url: source_url, fetch_metadata: fetch_metadata).call

      normalize_report(probe_result).merge(
        http_status: fetch_metadata[:http_status],
        fetch_metadata: fetch_metadata
      )
    end

    def normalize_report(result)
      {
        status: result[:status],
        source_url: result[:source_url],
        html_bytes: result[:html_bytes],
        title_detected: result[:title_detected],
        title: result[:title],
        trust_score_detected: result[:trust_score_detected],
        trust_score: result[:trust_score],
        rating_distribution_detected: result[:rating_distribution_detected],
        review_count_detected: result[:review_count_detected],
        review_count: result[:review_count],
        usable_raw_review_body_count: result[:usable_raw_review_count],
        minimum_usable_review_bodies: result[:minimum_usable_reviews],
        strong_usable_review_bodies: result[:strong_usable_reviews],
        trustpilot_ai_summary_detected: result[:trustpilot_ai_summary_detected],
        captcha_block_detected: result[:captcha_or_block_detected],
        corpus_quality: result[:corpus_quality],
        recommended_adapter: result[:recommended_adapter]
      }
    end

    def failure_report(source_url:, status:, error_code:, fetch_metadata:)
      {
        status: status,
        http_status: fetch_metadata[:http_status],
        source_url: source_url,
        html_bytes: fetch_metadata[:html_bytes],
        title_detected: false,
        title: nil,
        trust_score_detected: false,
        trust_score: nil,
        rating_distribution_detected: false,
        review_count_detected: false,
        review_count: nil,
        usable_raw_review_body_count: 0,
        minimum_usable_review_bodies: ReviewPlatforms::TrustpilotProbe::MINIMUM_USABLE_REVIEWS,
        strong_usable_review_bodies: ReviewPlatforms::TrustpilotProbe::STRONG_USABLE_REVIEWS,
        trustpilot_ai_summary_detected: false,
        captcha_block_detected: false,
        corpus_quality: "fail",
        recommended_adapter: "manual_import",
        error_code: error_code,
        fetch_metadata: fetch_metadata
      }
    end

    def exit_status_for(report)
      report[:corpus_quality] == "fail" ? 1 : 0
    end

    def expand_path(path)
      pathname = Pathname.new(path)
      pathname.absolute? ? pathname.to_s : Rails.root.join(path).to_s
    end
  end
end
