module Ingestion
  class SummaryBuilder
    def initialize(product:)
      @product = product
    end

    def call
      reviews = @product.reviews
      rated_reviews = reviews.where.not(rating: nil)

      @product.update!(
        reviews_count: reviews.count,
        average_rating: average_rating(rated_reviews),
        rating_distribution: rating_distribution(rated_reviews),
        sentiment_distribution: reviews.group(:sentiment).count,
        oldest_review_at: reviews.minimum(:review_date),
        newest_review_at: reviews.maximum(:review_date),
        ingestion_summary: {
          reviews_imported: reviews.count,
          source_platform: @product.platform,
          source_url: @product.source_url
        }
      )
    end

    private
      def average_rating(rated_reviews)
        rated_reviews.average(:rating)&.round(2)
      end

      def rating_distribution(rated_reviews)
        rated_reviews.group(:rating).count.transform_keys(&:to_s)
      end
  end
end
