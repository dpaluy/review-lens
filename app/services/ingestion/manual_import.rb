module Ingestion
  class ManualImport
    NO_USABLE_REVIEWS_ERROR = "No usable manual review blocks were provided."
    MISSING_FILE_ERROR = "No reviews file was attached to this ingestion run."
    SUMMARIZATION_FAILURE_MESSAGE = "Review summarization failed: %s"

    def initialize(product:, ingestion_run:)
      @product = product
      @ingestion_run = ingestion_run
    end

    def call
      return mark_failed(MISSING_FILE_ERROR) unless @ingestion_run.reviews_file.attached?

      @product.update!(ingestion_status: "parsing", ingestion_error: nil)
      @ingestion_run.update!(status: "parsing", started_at: Time.current, parser_version: "manual-v1")

      reviews = ReviewPlatforms::ManualAdapter
        .new(source_url: @product.source_url)
        .parse_reviews(@ingestion_run.reviews_file.download)

      import_result = Ingestion::Importer.import(@product, reviews)

      @ingestion_run.update!(
        reviews_found: reviews.size,
        reviews_imported: import_result.imported,
        reviews_skipped: import_result.skipped
      )

      if import_result.imported.zero?
        mark_failed(NO_USABLE_REVIEWS_ERROR)
      else
        mark_ready
      end
    rescue StandardError => error
      mark_failed(error.message)
    end

    private
    def mark_ready
      @product.update!(ingestion_status: "summarizing")
      @ingestion_run.update!(status: "summarizing")

      Ingestion::SummaryBuilder.new(product: @product).call
      summarize_reviews

      @product.update!(ingestion_status: "ready", ingestion_error: nil)
      @ingestion_run.update!(status: "ready", finished_at: Time.current)
    end

    def summarize_reviews
      ReviewAnalysis::BatchSummarizer.call(product: @product)
    rescue StandardError => error
      raise StandardError, SUMMARIZATION_FAILURE_MESSAGE % error.message
    end

    def mark_failed(error_message)
      @product.update!(ingestion_status: "failed", ingestion_error: error_message)
      @ingestion_run.update!(status: "failed", error: error_message, finished_at: Time.current)
    end
  end
end
