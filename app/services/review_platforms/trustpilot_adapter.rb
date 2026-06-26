require "digest"

module ReviewPlatforms
  class TrustpilotAdapter
    PARSER_VERSION = "trustpilot-html-v1"
    REVIEW_CARD_SELECTORS = [
      "[data-service-review-card-paper]",
      "article[data-testid='review-card']",
      "article[data-review-id]",
      "[data-review-id]"
    ].freeze

    def valid_url?(url)
      Product.source_identity(url).present?
    end

    def external_id(url)
      Product.source_identity(url)&.fetch(:external_id)
    end

    def canonical_url(url)
      identity = Product.source_identity(url)
      return unless identity

      "https://www.trustpilot.com/review/#{identity[:external_id]}"
    end

    def fetch_pages(_url)
      raise NotImplementedError, "Network fetching belongs to the ingestion fetcher"
    end

    def parse_reviews(page_html, source_url:)
      document = Nokogiri::HTML(page_html)

      review_cards(document).filter_map do |card|
        parsed_review(card, source_url:)
      end
    end

    def parse_product_metadata(page_html)
      document = Nokogiri::HTML(page_html)

      { name: product_name(document) }.compact
    end

    private
      def product_name(document)
        heading = normalize_text(document.at_css("h1")&.text)
        title = normalize_text(document.at_css("title")&.text)

        normalize_product_name(heading || title)
      end

      def normalize_product_name(text)
        normalize_text(text)
          &.sub(/\s+\|\s+Trustpilot\z/, "")
          &.sub(/\s+Reviews\z/, "")
          &.presence
      end

      def review_cards(document)
        REVIEW_CARD_SELECTORS.flat_map { |selector| document.css(selector).to_a }.uniq
      end

      def parsed_review(card, source_url:)
        body = text_at(card, [
          "[data-service-review-text-typography]",
          "[itemprop='reviewBody']",
          "p"
        ])
        title = text_at(card, [
          "[data-service-review-title-typography]",
          "h2",
          "h3"
        ])
        rating = extract_rating(card)
        reviewer_label = text_at(card, [
          "[data-consumer-name-typography]",
          "[data-testid='consumer-name']",
          "[itemprop='author']",
          "aside a",
          "aside span"
        ])
        external_review_id = extract_external_review_id(card)
        normalized_body = normalize_text(body)

        return if normalized_body.blank?

        {
          external_review_id: external_review_id,
          content_hash: content_hash(normalized_body, rating:, reviewer_label:),
          source_url: review_source_url(card, source_url),
          rating: rating,
          title: normalize_text(title),
          body: normalized_body,
          reviewer_label: normalize_text(reviewer_label),
          review_date: extract_review_date(card),
          raw_payload: {
            parser: PARSER_VERSION,
            external_review_id: external_review_id,
            rating: rating,
            title: normalize_text(title),
            body: normalized_body,
            reviewer_label: normalize_text(reviewer_label)
          }.compact
        }.compact
      end

      def text_at(node, selectors)
        selectors.each do |selector|
          text = normalize_text(node.at_css(selector)&.text)
          return text if text.present?
        end

        nil
      end

      def normalize_text(text)
        text.to_s.squish.presence
      end

      def extract_rating(card)
        raw_rating =
          card["data-service-review-rating"] ||
          card["data-rating"] ||
          card.at_css("[data-service-review-rating]")&.[]("data-service-review-rating") ||
          card.at_css("[itemprop='ratingValue']")&.[]("content") ||
          card.at_css("img[alt*='Rated']")&.[]("alt")

        raw_rating.to_s[/\d+/]&.to_i
      end

      def extract_external_review_id(card)
        raw_id =
          card["data-service-review-id"] ||
          card["data-review-id"] ||
          card.at_css("a[href*='/reviews/']")&.[]("href")&.split("/reviews/")&.last

        normalize_text(raw_id)&.split(/[?#]/)&.first
      end

      def extract_review_date(card)
        raw_date =
          card.at_css("time")&.[]("datetime") ||
          card.at_css("[data-service-review-date-time-ago]")&.[]("datetime")

        Time.zone.parse(raw_date) if raw_date.present?
      rescue ArgumentError
        nil
      end

      def review_source_url(card, source_url)
        review_path = card.at_css("a[href*='/reviews/']")&.[]("href")
        return source_url if review_path.blank?

        URI.join(source_url, review_path).to_s
      rescue URI::InvalidURIError
        source_url
      end

      def content_hash(body, rating:, reviewer_label:)
        Digest::SHA256.hexdigest([ body, rating, normalize_text(reviewer_label) ].compact.join("\n"))
      end
  end
end
