#!/usr/bin/env ruby

require_relative "../config/environment"
require "json"
require "optparse"

options = {
  save_fixture: false,
  fixture_path: Rails.root.join("test/fixtures/files/trustpilot_quickbooks.html")
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: script/scrape_probe.rb URL [--save-fixture]"

  opts.on("--save-fixture", "Save fetched HTML to test/fixtures/files/trustpilot_quickbooks.html after a successful allowed fetch") do
    options[:save_fixture] = true
  end
end

parser.parse!

source_url = ARGV.first || "https://www.trustpilot.com/review/quickbooks.intuit.com"
fetch_result = Ingestion::Fetcher.new.fetch(source_url)

unless fetch_result.success?
  output = {
    status: "fetch_failed",
    error_code: fetch_result.error_code,
    corpus_quality: "fail",
    recommended_adapter: "manual_import",
    fetch_metadata: fetch_result.metadata
  }

  puts JSON.pretty_generate(output)
  exit 1
end

probe_result = ReviewPlatforms::TrustpilotProbe.new(
  html: fetch_result.body,
  source_url:,
  fetch_metadata: fetch_result.metadata
).call

if options[:save_fixture]
  File.write(options[:fixture_path], fetch_result.body)
  probe_result[:saved_fixture] = options[:fixture_path].to_s
end

puts JSON.pretty_generate(probe_result)

exit(probe_result[:corpus_quality] == "fail" ? 1 : 0)
