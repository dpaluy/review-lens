#!/usr/bin/env ruby

require_relative "../config/environment"
require_relative "scrape_probe_cli"

exit Script::ScrapeProbeCli.new.call(ARGV)
