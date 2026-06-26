require "json"
require "nokogiri"

module ReviewPlatforms
  class TrustpilotProbe
    MINIMUM_USABLE_REVIEWS = 20
    STRONG_USABLE_REVIEWS = 50
    REVIEW_TEXT_SELECTORS = [
      "[data-service-review-text-typography]",
      "[data-service-review-text]",
      "p[data-service-review-text-typography]",
      "article p"
    ].freeze
    BLOCK_PATTERNS = [
      /captcha/i,
      /access denied/i,
      /verify you are human/i,
      /unusual traffic/i,
      /security check/i
    ].freeze

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
        from_json_ld("ratingValue") || @html[/TrustScore\s*([0-9.]+)/i, 1]
      end

      def review_count
        raw_count = from_json_ld("reviewCount") || @html[/([0-9][0-9,.]*)\s+reviews/i, 1]
        return if raw_count.blank?

        raw_count.to_s.delete(",.").to_i
      end

      def from_json_ld(key)
        @document.css('script[type="application/ld+json"]').each do |script|
          parsed = JSON.parse(script.text)
          value = find_json_key(parsed, key)
          return value.to_s if value.present?
        rescue JSON::ParserError
          next
        end

        nil
      end

      def find_json_key(value, key)
        case value
        when Hash
          return value[key] if value.key?(key)

          value.each_value do |child|
            found = find_json_key(child, key)
            return found if found.present?
          end
        when Array
          value.each do |child|
            found = find_json_key(child, key)
            return found if found.present?
          end
        end

        nil
      end

      def rating_distribution_detected?
        text = @document.text
        %w[5-star 4-star 3-star 2-star 1-star].all? { |label| text.include?(label) }
      end

      def trustpilot_ai_summary_detected?
        @html.match?(/AI[- ]generated summary|AI[- ]created summary|Trustpilot AI/i)
      end

      def blocked?
        BLOCK_PATTERNS.any? { |pattern| @html.match?(pattern) }
      end

      def review_bodies
        REVIEW_TEXT_SELECTORS.flat_map { |selector| @document.css(selector).map { |node| node.text.squish } }
          .select { |body| usable_review_body?(body) }
          .uniq
      end

      def usable_review_body?(body)
        body.length >= 40 && body.split.size >= 8 && !body.match?(/Trustpilot AI|AI-generated summary/i)
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
  end
end
