require "json"
require "nokogiri"

module ReviewPlatforms
  class TrustpilotProbe
    MINIMUM_USABLE_REVIEWS = 20
    STRONG_USABLE_REVIEWS = 50
    REVIEW_TEXT_SELECTORS = [
      "[data-service-review-text-typography]",
      "[data-service-review-text]",
      "[itemprop='reviewBody']",
      "p[data-service-review-text-typography]",
      "article p"
    ].freeze
    BLOCK_PATTERNS = [
      /captcha/i,
      /access denied/i,
      /verify you are human/i,
      /unusual traffic/i,
      /security check/i,
      /verifying your connection/i,
      /awswaf\.com/i
    ].freeze
    BLOCKED_HTTP_STATUSES = [ 403, 429 ].freeze

    def initialize(html:, source_url:, fetch_metadata: {})
      @html = html.to_s
      @source_url = source_url
      @fetch_metadata = fetch_metadata
      @document = Nokogiri::HTML(@html)
    end

    def call
      usable_raw_review_count = review_bodies.count
      captcha_or_block_detected = blocked?
      corpus_quality = classify(usable_raw_review_count, captcha_or_block_detected)

      {
        status: captcha_or_block_detected ? "blocked" : "ok",
        source_url: @source_url,
        html_bytes: @html.bytesize,
        title: title,
        title_detected: title.present?,
        trust_score: trust_score,
        trust_score_detected: trust_score.present?,
        rating_distribution_detected: rating_distribution_detected?,
        review_count: review_count,
        review_count_detected: review_count.present?,
        usable_raw_review_count:,
        minimum_usable_reviews: MINIMUM_USABLE_REVIEWS,
        strong_usable_reviews: STRONG_USABLE_REVIEWS,
        trustpilot_ai_summary_detected: trustpilot_ai_summary_detected?,
        captcha_or_block_detected:,
        corpus_quality:,
        recommended_adapter: recommended_adapter(corpus_quality),
        fetch_metadata: @fetch_metadata
      }
    end

    private

    def title
      @title ||= @document.at_css("title")&.text.to_s.squish.presence
    end

    def trust_score
      @trust_score ||= json_ld_aggregate_rating["ratingValue"]&.to_s ||
        @html[/TrustScore\s*([0-9.]+)/i, 1]
    end

    def review_count
      @review_count ||= begin
        raw_count = json_ld_aggregate_rating["reviewCount"] ||
          @html[/([0-9][0-9,.\s]*)\s+reviews/i, 1]
        normalize_count(raw_count)
      end
    end

    def rating_distribution_detected?
      @rating_distribution_detected ||= begin
        distribution_text = @document.text

        %w[5-star 4-star 3-star 2-star 1-star].all? do |label|
          distribution_text.match?(/#{Regexp.escape(label)}/i) || distribution_text.match?(/#{label.first}\s+star/i)
        end
      end
    end

    def trustpilot_ai_summary_detected?
      @trustpilot_ai_summary_detected ||= @html.match?(/AI[- ]generated summary|AI[- ]created summary|Trustpilot AI/i)
    end

    def blocked?
      blocked_http_status? || BLOCK_PATTERNS.any? { |pattern| @html.match?(pattern) }
    end

    def blocked_http_status?
      BLOCKED_HTTP_STATUSES.include?(@fetch_metadata[:http_status].to_i)
    end

    def review_bodies
      @review_bodies ||= REVIEW_TEXT_SELECTORS.flat_map do |selector|
        @document.css(selector).map { |node| node.text.squish }
      end.select { |body| usable_review_body?(body) }.uniq
    end

    def usable_review_body?(body)
      body.length >= 40 &&
        body.split.size >= 8 &&
        !body.match?(/Trustpilot AI|AI[- ]generated summary|AI[- ]created summary/i)
    end

    def classify(usable_raw_review_count, captcha_or_block_detected)
      return "fail" if captcha_or_block_detected || usable_raw_review_count.zero?
      return "strong" if usable_raw_review_count >= STRONG_USABLE_REVIEWS
      return "viable" if usable_raw_review_count >= MINIMUM_USABLE_REVIEWS

      "thin"
    end

    def recommended_adapter(corpus_quality)
      %w[strong viable].include?(corpus_quality) ? "trustpilot" : "manual_import"
    end

    def json_ld_aggregate_rating
      @json_ld_aggregate_rating ||= json_ld_objects.filter_map { |object| find_aggregate_rating(object) }.first || {}
    end

    def json_ld_objects
      @json_ld_objects ||= @document.css("script[type='application/ld+json']").filter_map do |script|
        JSON.parse(script.text)
      rescue JSON::ParserError
        nil
      end
    end

    def find_aggregate_rating(value)
      case value
      when Hash
        return value["aggregateRating"] if value["aggregateRating"].is_a?(Hash)

        value.each_value do |nested_value|
          rating = find_aggregate_rating(nested_value)
          return rating if rating.present?
        end
      when Array
        value.each do |nested_value|
          rating = find_aggregate_rating(nested_value)
          return rating if rating.present?
        end
      end

      nil
    end

    def normalize_count(raw_count)
      return if raw_count.blank?

      raw_count.to_s.gsub(/[^\d]/, "").presence&.to_i
    end
  end
end
