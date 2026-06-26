require "net/http"
require "timeout"

module Ingestion
  class Fetcher
    TRUSTPILOT_HOSTS = %w[trustpilot.com www.trustpilot.com].freeze
    MAX_REDIRECTS = 2
    TIMEOUT_SECONDS = 10
    MAX_BYTES = 5.megabytes

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

        if redirect_status?(status)
          redirects += 1
          return failure("too_many_redirects", metadata.merge(final_url: uri.to_s)) if redirects > MAX_REDIRECTS

          redirect_uri = resolve_redirect(uri, response.headers["location"] || response.headers[:location])
          return failure("invalid_redirect", metadata.merge(final_url: uri.to_s)) unless redirect_uri&.is_a?(URI::HTTP)
          return failure("redirect_host_not_allowed", metadata.merge(final_url: redirect_uri.to_s)) unless allowed_host?(redirect_uri)

          uri = redirect_uri
          next
        end

        body = response.body.to_s
        html_bytes = body.bytesize
        return failure("response_too_large", metadata.merge(final_url: uri.to_s, html_bytes:, max_bytes: MAX_BYTES)) if html_bytes > MAX_BYTES

        metadata[:pages_succeeded] = status.between?(200, 299) ? 1 : 0
        metadata[:status_code] = status
        metadata[:final_url] = uri.to_s
        metadata[:html_bytes] = html_bytes

        return Result.new(
          successful: status.between?(200, 299),
          body:,
          metadata:,
          error_code: (status.between?(200, 299) ? nil : "http_error")
        )
      end
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
      failure("timeout", metadata)
    rescue SocketError, SystemCallError => error
      failure("network_error", metadata.merge(error_class: error.class.name))
    end

    private
      def perform_request(uri, limits)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: limits[:timeout_seconds], read_timeout: limits[:timeout_seconds]) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = "ReviewLensAI/1.0 public-review-probe"
          request["Accept"] = "text/html,application/xhtml+xml"

          body = +""
          response = http.request(request) do |streaming_response|
            streaming_response.read_body do |chunk|
              body << chunk
              raise ResponseTooLarge if body.bytesize > limits[:max_bytes]
            end
          end

          Response.new(status: response.code.to_i, headers: response.each_header.to_h, body:)
        end
      rescue ResponseTooLarge
        Response.new(status: 200, headers: {}, body: "x" * (limits[:max_bytes] + 1))
      end

      def request_limits
        { timeout_seconds: TIMEOUT_SECONDS, max_bytes: MAX_BYTES }
      end

      def base_metadata(source_url)
        {
          source_url:,
          pages_attempted: 0,
          pages_succeeded: 0,
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
        [ 301, 302, 303, 307, 308 ].include?(status)
      end

      def resolve_redirect(current_uri, location)
        return if location.blank?

        current_uri + location
      rescue URI::InvalidURIError
        nil
      end

      def failure(error_code, metadata)
        Result.new(successful: false, body: nil, metadata:, error_code:)
      end

      class ResponseTooLarge < StandardError; end
  end
end
