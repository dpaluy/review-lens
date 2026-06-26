module ReviewPlatforms
  class ManualAdapter
    def initialize(source_url:)
      @source_url = source_url
    end

    def parse_reviews(pasted_reviews)
      review_blocks(pasted_reviews).map do |body|
        {
          external_review_id: nil,
          content_hash: nil,
          source_url: @source_url,
          rating: nil,
          title: body.lines.first&.strip,
          body:,
          reviewer_label: "Manual import",
          reviewer_role: nil,
          reviewer_company_size: nil,
          review_date: nil,
          raw_payload: { import_mode: "manual" }
        }
      end
    end

    private
      def review_blocks(pasted_reviews)
        pasted_reviews.to_s
          .gsub("\r\n", "\n")
          .split(/\n[[:blank:]]*\n+/)
          .map(&:strip)
          .reject(&:blank?)
      end
  end
end
