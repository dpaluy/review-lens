module ReviewAnalysis
  class BatchSummarizer
    DEFAULT_BATCH_SIZE = 30

    SUMMARY_KEYS = %w[
      pain_points
      praised_features
      feature_requests
      buyer_objections
      sentiment_patterns
      representative_quotes
      supporting_review_ids
    ].freeze

    Result = Data.define(:batches_count, :reviews_count)

    class RubyLLMClient
      INSTRUCTIONS = <<~TEXT.squish
        Summarize only the supplied reviews. Use the review_id values provided.
        Do not use outside product knowledge. Preserve supporting review IDs for
        every conclusion whenever possible.
      TEXT

      SCHEMA = {
        name: "batch_review_summary",
        strict: true,
        schema: {
          type: "object",
          additionalProperties: false,
          required: SUMMARY_KEYS,
          properties: {
            pain_points: { type: "array", items: { "$ref" => "#/$defs/theme" } },
            praised_features: { type: "array", items: { "$ref" => "#/$defs/theme" } },
            feature_requests: { type: "array", items: { "$ref" => "#/$defs/theme" } },
            buyer_objections: { type: "array", items: { "$ref" => "#/$defs/theme" } },
            sentiment_patterns: { type: "array", items: { "$ref" => "#/$defs/theme" } },
            representative_quotes: { type: "array", items: { "$ref" => "#/$defs/quote" } },
            supporting_review_ids: { type: "array", items: { type: "string" } }
          },
          "$defs" => {
            theme: {
              type: "object",
              additionalProperties: false,
              required: %w[theme summary supporting_review_ids],
              properties: {
                theme: { type: "string" },
                summary: { type: "string" },
                supporting_review_ids: { type: "array", items: { type: "string" } }
              }
            },
            quote: {
              type: "object",
              additionalProperties: false,
              required: %w[review_id quote theme],
              properties: {
                review_id: { type: "string" },
                quote: { type: "string" },
                theme: { type: "string" }
              }
            }
          }
        }
      }.freeze

      def summarize(reviews:)
        response = RubyLLM.chat
          .with_instructions(INSTRUCTIONS)
          .with_schema(SCHEMA)
          .ask(prompt_for(reviews))

        response.content
      end

      private
        def prompt_for(reviews)
          <<~TEXT
            Create one grounded batch summary for these reviews.

            Reviews:
            #{reviews.to_json}
          TEXT
        end
    end

    def self.call(product:, batch_size: DEFAULT_BATCH_SIZE, client: RubyLLMClient.new)
      new(product:, batch_size:, client:).call
    end

    def initialize(product:, batch_size: DEFAULT_BATCH_SIZE, client: RubyLLMClient.new)
      @product = product
      @batch_size = batch_size
      @client = client
    end

    def call
      reviews = ordered_reviews.to_a

      InsightBatch.transaction do
        product.insight_batches.destroy_all

        reviews.each_slice(batch_size).with_index do |batch, index|
          product.insight_batches.create!(
            batch_index: index,
            reviews_count: batch.size,
            review_ids: batch.map(&:id),
            summary: summary_for(batch)
          )
        end
      end

      Result.new(product.insight_batches.count, reviews.size)
    end

    private
      attr_reader :product, :batch_size, :client

      def ordered_reviews
        product.reviews.order(:id)
      end

      def summary_for(reviews)
        normalize_summary client.summarize(reviews: reviews.map { |review| review_payload(review) })
      end

      def review_payload(review)
        {
          review_id: review.id.to_s,
          external_review_id: review.external_review_id,
          rating: review.rating&.to_s,
          sentiment: review.sentiment,
          title: review.title,
          body: review.body,
          reviewer_label: review.reviewer_label,
          reviewer_role: review.reviewer_role,
          reviewer_company_size: review.reviewer_company_size,
          review_date: review.review_date&.iso8601
        }.compact
      end

      def normalize_summary(summary)
        summary = summary.to_h.stringify_keys

        SUMMARY_KEYS.index_with { |key| Array(summary[key]) }
      end
  end
end
