module ReviewAnalysis
  class ContextBuilder
    DEFAULT_REVIEW_LIMIT = 50
    STOP_WORDS = %w[
      a an and are as at be by do does for from give how in is it me of on or
      our the these this to users what which with
    ].freeze

    Result = Data.define(:data, :text, :review_ids)

    def initialize(product:, question:, review_limit: DEFAULT_REVIEW_LIMIT)
      @product = product
      @question = question.to_s
      @review_limit = review_limit
    end

    def call
      reviews = matching_reviews
      data = {
        product: product_context,
        insight_batches: insight_batch_context,
        reviews: reviews.map { |review| review_context(review) }
      }

      Result.new(data:, text: text_context(data), review_ids: reviews.map(&:id))
    end

    private
      attr_reader :product, :question, :review_limit

      def matching_reviews
        relation = product.reviews.order(:id)
        matched = keyword_terms.reduce(nil) do |scope, term|
          term_scope = relation.where(
            "title ILIKE :term OR body ILIKE :term OR reviewer_label ILIKE :term OR reviewer_role ILIKE :term",
            term: "%#{Review.sanitize_sql_like(term)}%"
          )
          scope ? scope.or(term_scope) : term_scope
        end

        scope = matched&.exists? ? matched : relation
        scope.limit(review_limit).to_a
      end

      def keyword_terms
        @keyword_terms ||= question.downcase.scan(/[a-z0-9]+/).reject do |word|
          word.length < 3 || STOP_WORDS.include?(word)
        end.uniq.first(8)
      end

      def product_context
        {
          id: product.id,
          name: product.name,
          platform: product.platform,
          source_url: product.source_url,
          reviews_count: product.reviews_count,
          average_rating: product.average_rating&.to_s,
          rating_distribution: product.rating_distribution,
          sentiment_distribution: product.sentiment_distribution,
          ingestion_summary: product.ingestion_summary
        }.compact
      end

      def insight_batch_context
        product.insight_batches.order(:batch_index).map do |batch|
          {
            batch_index: batch.batch_index,
            reviews_count: batch.reviews_count,
            review_ids: batch.review_ids.map(&:to_s),
            summary: batch.summary
          }
        end
      end

      def review_context(review)
        {
          id: review.id,
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

      def text_context(data)
        [
          product_text(data.fetch(:product)),
          insight_batches_text(data.fetch(:insight_batches)),
          reviews_text(data.fetch(:reviews))
        ].compact_blank.join("\n\n")
      end

      def product_text(product_data)
        <<~TEXT.squish
          Product: #{product_data[:name]}.
          Platform: #{product_data[:platform]}.
          Reviews count: #{product_data[:reviews_count]}.
          Average rating: #{product_data[:average_rating] || "unknown"}.
          Rating distribution: #{product_data[:rating_distribution]}.
          Sentiment distribution: #{product_data[:sentiment_distribution]}.
          Ingestion summary: #{product_data[:ingestion_summary]}.
        TEXT
      end

      def insight_batches_text(batches)
        return nil if batches.empty?

        batches.map do |batch|
          "Insight batch #{batch[:batch_index]}: #{batch[:summary]}"
        end.join("\n")
      end

      def reviews_text(reviews)
        return nil if reviews.empty?

        reviews.map do |review|
          [
            "Review #{review[:id]}",
            "External ID: #{review[:external_review_id]}",
            "Rating: #{review[:rating] || "unknown"}",
            "Sentiment: #{review[:sentiment]}",
            "Title: #{review[:title]}",
            "Body: #{review[:body]}",
            "Reviewer: #{review[:reviewer_label]}"
          ].compact.join("\n")
        end.join("\n\n")
      end
  end
end
