require "net/http"
require "timeout"

module Ingestion
  class Fetcher
    TRUSTPILOT_HOSTS = %w[trustpilot.com www.trustpilot.com].freeze
    MAX_REDIRECTS = 2
    TIMEOUT_SECONDS = 10
    MAX_BYTES = 5.megabytes
    REDIRECT_STATUSES = [ 301, 302, 303, 307, 308 ].freeze
    BLOCKED_HTTP_STATUSES = [ 403, 429 ].freeze

    Result = Struct.new(:successful, :body, :metadata, :error_code, keyword_init: true) do
      def success?
        successful
      end
    end

    Response = Struct.new(:status, :headers, :body, keyword_init: true)

    def initialize(transport: nil)
      @transport = transport || method(:perform_request)
    end

    def fetch(source_url)
      uri = parse_uri(source_url)
      metadata = base_metadata(source_url)

      return failure("invalid_url", metadata) unless uri&.is_a?(URI::HTTP)
      return failure("unsupported_host", metadata.merge(final_url: uri.to_s)) unless allowed_host?(uri)

      redirects = 0

      loop do
        metadata[:pages_attempted] += 1
        response = @transport.call(uri, request_limits)
        status = response.status.to_i
        metadata[:http_status] = status

        if redirect_status?(status)
          redirects += 1
          metadata[:redirect_count] = redirects
          return failure("too_many_redirects", metadata.merge(final_url: uri.to_s)) if redirects > MAX_REDIRECTS

          redirect_uri = resolve_redirect(uri, header_value(response.headers, "location"))
          return failure("invalid_redirect", metadata.merge(final_url: uri.to_s)) unless redirect_uri&.is_a?(URI::HTTP)
          return failure("redirect_host_not_allowed", metadata.merge(final_url: redirect_uri.to_s)) unless allowed_host?(redirect_uri)

          uri = redirect_uri
          next
        end

        unless success_status?(status)
          return failure(http_error_code(status), metadata.merge(final_url: uri.to_s))
        end

        body = response.body.to_s
        html_bytes = body.bytesize
        return failure("response_too_large", metadata.merge(final_url: uri.to_s, html_bytes:, max_bytes: MAX_BYTES)) if html_bytes > MAX_BYTES

        metadata[:pages_succeeded] += 1
        metadata[:final_url] = uri.to_s
        metadata[:html_bytes] = html_bytes
        metadata[:content_type] = header_value(response.headers, "content-type")

        return Result.new(successful: true, body:, metadata:, error_code: nil)
      end
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
      failure("timeout", metadata)
    rescue ResponseTooLarge
      failure("response_too_large", metadata.merge(final_url: uri&.to_s, max_bytes: MAX_BYTES))
    rescue SocketError, SystemCallError
      failure("network_error", metadata)
    end

    private

    def perform_request(uri, limits)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "ReviewLensAI/1.0"
      request["Accept"] = "text/html,application/xhtml+xml"

      body = +""
      response_headers = {}
      response_status = nil

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: limits[:timeout_seconds],
        read_timeout: limits[:timeout_seconds]
      ) do |http|
        http.request(request) do |response|
          response_status = response.code.to_i
          response.each_header { |key, value| response_headers[key] = value }
          response.read_body do |chunk|
            body << chunk
            raise ResponseTooLarge if body.bytesize > limits[:max_bytes]
          end
        end
      end

      Response.new(status: response_status, headers: response_headers, body:)
    end

    def request_limits
      { timeout_seconds: TIMEOUT_SECONDS, max_bytes: MAX_BYTES }
    end

    def base_metadata(source_url)
      {
        source_url:,
        pages_attempted: 0,
        pages_succeeded: 0,
        redirect_count: 0,
        timeout_seconds: TIMEOUT_SECONDS,
        max_bytes: MAX_BYTES
      }
    end

    def parse_uri(source_url)
      URI.parse(source_url.to_s.strip)
    rescue URI::InvalidURIError
      nil
    end

    def allowed_host?(uri)
      TRUSTPILOT_HOSTS.include?(uri.host.to_s.downcase)
    end

    def redirect_status?(status)
      REDIRECT_STATUSES.include?(status)
    end

    def success_status?(status)
      status.between?(200, 299)
    end

    def http_error_code(status)
      return "blocked" if BLOCKED_HTTP_STATUSES.include?(status)

      "http_#{status}"
    end

    def resolve_redirect(current_uri, location)
      return if location.blank?

      current_uri + location
    rescue URI::InvalidURIError
      nil
    end

    def header_value(headers, name)
      headers.find { |key, _value| key.to_s.downcase == name }&.last
    end

    def failure(error_code, metadata)
      Result.new(successful: false, body: nil, metadata:, error_code:)
    end

    class ResponseTooLarge < StandardError; end
  end
end
