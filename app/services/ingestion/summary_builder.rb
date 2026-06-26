module Ingestion
  class SummaryBuilder
    FIELD_COVERAGE_COLUMNS = {
      body: :body,
      rating: :rating,
      review_date: :review_date,
      reviewer_label: :reviewer_label,
      reviewer_role: :reviewer_role,
      reviewer_company_size: :reviewer_company_size,
      title: :title
    }.freeze

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
          usable_review_count: reviews.count,
          corpus_quality: corpus_quality(reviews.count),
          field_coverage: field_coverage(reviews),
          source_platform: @product.platform,
          source_url: @product.source_url
        }
      )
    end

    private
      def corpus_quality(usable_review_count)
        usable_review_count < Product::MINIMUM_USABLE_REVIEW_COUNT ? "thin" : "viable"
      end

      def field_coverage(reviews)
        total = reviews.count

        FIELD_COVERAGE_COLUMNS.each_with_object({}) do |(field_name, column_name), coverage|
          present_count = present_count(reviews, column_name)

          coverage[field_name.to_s] = {
            "present" => present_count,
            "total" => total,
            "percentage" => coverage_percentage(present_count, total)
          }
        end
      end

      def present_count(reviews, column_name)
        present_reviews = reviews.where.not(column_name => nil)
        return present_reviews.count unless blankable_column?(column_name)

        column = Review.connection.quote_column_name(column_name)

        present_reviews.where.not("#{column} = ?", "").count
      end

      def blankable_column?(column_name)
        Review.type_for_attribute(column_name.to_s).type.in?([ :string, :text ])
      end

      def coverage_percentage(present_count, total)
        return 0 if total.zero?

        ((present_count.to_f / total) * 100).round
      end

      def average_rating(rated_reviews)
        rated_reviews.average(:rating)&.round(2)
      end

      def rating_distribution(rated_reviews)
        rated_reviews.group(:rating).count.transform_keys do |rating|
          rating.to_i == rating ? rating.to_i.to_s : rating.to_s
        end
      end
  end
end
