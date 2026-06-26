module ReviewPlatforms
  class ManualAdapter
    BODY_HEADERS = %w[body review review_body content text].freeze
    TITLE_HEADERS = %w[title headline summary].freeze
    REVIEWER_HEADERS = %w[reviewer reviewer_label author name].freeze
    ROLE_HEADERS = %w[reviewer_role role title_role].freeze
    COMPANY_SIZE_HEADERS = %w[reviewer_company_size company_size company].freeze
    DATE_HEADERS = %w[date review_date created_at].freeze
    RATING_HEADERS = %w[rating stars score].freeze
    EXTERNAL_ID_HEADERS = %w[external_review_id review_id id].freeze
    SOURCE_URL_HEADERS = %w[source_url url].freeze

    def initialize(source_url:)
      @source_url = source_url
    end

    def parse_reviews(pasted_reviews)
      csv_reviews = parse_csv_reviews(pasted_reviews)
      return csv_reviews if csv_reviews.any?

      review_blocks(pasted_reviews).map do |body|
        review_hash(
          body: body,
          title: body.lines.first&.strip,
          raw_payload: { import_mode: "manual" }
        )
      end
    end

    private

    def parse_csv_reviews(pasted_reviews)
      table = CSV.parse(pasted_reviews.to_s, headers: true, skip_blanks: true)
      return [] unless csv_table?(table)

      table.filter_map do |row|
        row_hash = row.to_h.transform_keys { |key| key.to_s.strip.downcase }
        body = value_for(row_hash, BODY_HEADERS)
        next if body.blank?

        review_hash(
          external_review_id: value_for(row_hash, EXTERNAL_ID_HEADERS),
          source_url: value_for(row_hash, SOURCE_URL_HEADERS).presence || @source_url,
          rating: parse_rating(value_for(row_hash, RATING_HEADERS)),
          title: value_for(row_hash, TITLE_HEADERS).presence || body.lines.first&.strip,
          body: body,
          reviewer_label: value_for(row_hash, REVIEWER_HEADERS).presence || "Manual import",
          reviewer_role: value_for(row_hash, ROLE_HEADERS),
          reviewer_company_size: value_for(row_hash, COMPANY_SIZE_HEADERS),
          review_date: parse_review_date(value_for(row_hash, DATE_HEADERS)),
          raw_payload: { import_mode: "manual_csv", row: row_hash.compact_blank }
        )
      end
    rescue CSV::MalformedCSVError
      []
    end

    def csv_table?(table)
      headers = Array(table.headers).map { |header| header.to_s.strip.downcase }
      headers.intersect?(BODY_HEADERS)
    end

    def value_for(row_hash, headers)
      headers.lazy.map { |header| row_hash[header].to_s.strip.presence }.find(&:present?)
    end

    def parse_rating(value)
      return if value.blank?

      BigDecimal(value)
    rescue ArgumentError
      nil
    end

    def parse_review_date(value)
      return if value.blank?

      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def review_hash(
      body:,
      title: nil,
      external_review_id: nil,
      source_url: @source_url,
      rating: nil,
      reviewer_label: "Manual import",
      reviewer_role: nil,
      reviewer_company_size: nil,
      review_date: nil,
      raw_payload: {}
    )
      {
        external_review_id: external_review_id,
        content_hash: nil,
        source_url: source_url,
        rating: rating,
        title: title,
        body: body,
        reviewer_label: reviewer_label,
        reviewer_role: reviewer_role,
        reviewer_company_size: reviewer_company_size,
        review_date: review_date,
        raw_payload: raw_payload
      }
    end

    def review_blocks(pasted_reviews)
      pasted_reviews.to_s
        .gsub("\r\n", "\n")
        .split(/\n[[:blank:]]*\n+/)
        .map(&:strip)
        .reject(&:blank?)
    end
  end
end
