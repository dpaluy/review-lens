class IngestReviewsJob < ApplicationJob
  queue_as :default

  FETCH_FAILURE_MESSAGE = "Trustpilot fetch failed: %s"
  FETCH_BLOCKED_MESSAGE = "Trustpilot fetch blocked by remote host"
  NO_USABLE_REVIEWS_MESSAGE = "No usable Trustpilot review cards found. Use manual import or another public Trustpilot URL."
  SUMMARIZATION_FAILURE_MESSAGE = "Review summarization failed: %s"
  BLOCKED_WARNING = "Trustpilot returned blocking page before parsing"
  THIN_CORPUS_WARNING = "Trustpilot returned fewer than 20 usable raw reviews; manual import recommended"

  discard_on ActiveJob::DeserializationError

  def perform(ingestion_run)
    @ingestion_run = ingestion_run
    @product = ingestion_run.product
    @adapter = ReviewPlatforms::TrustpilotAdapter.new

    mark_fetching

    fetch_result = Ingestion::Fetcher.new.fetch(product.source_url)
    update_fetch_counters(fetch_result.metadata)

    return mark_failed(fetch_failure_message(fetch_result.error_code)) unless fetch_result.success?

    probe_result = probe(fetch_result)
    ingestion_run.update!(
      raw_fetch_metadata: { fetch: fetch_result.metadata, probe: probe_result },
      warnings: probe_warnings(probe_result)
    )

    return mark_failed(FETCH_BLOCKED_MESSAGE) if probe_result[:captcha_or_block_detected]

    mark_parsing

    parsed_reviews = adapter.parse_reviews(fetch_result.body, source_url: product.source_url)
    update_product_metadata(fetch_result.body)
    import_result = Ingestion::Importer.import(product, parsed_reviews)

    ingestion_run.update!(
      reviews_found: parsed_reviews.size,
      reviews_imported: import_result.imported,
      reviews_skipped: import_result.skipped
    )

    return mark_failed(NO_USABLE_REVIEWS_MESSAGE) if product.reviews.reload.none?

    mark_ready
  rescue StandardError => error
    mark_failed(error.message)
  end

  private
    attr_reader :adapter, :ingestion_run, :product

    def mark_fetching
      product.update!(ingestion_status: "fetching", ingestion_error: nil)
      ingestion_run.update!(
        status: "fetching",
        started_at: Time.current,
        parser_version: ReviewPlatforms::TrustpilotAdapter::PARSER_VERSION,
        error: nil,
        warnings: [],
        raw_fetch_metadata: {}
      )
    end

    def mark_parsing
      product.update!(ingestion_status: "parsing")
      ingestion_run.update!(status: "parsing")
    end

    def mark_ready
      product.update!(ingestion_status: "summarizing")
      ingestion_run.update!(status: "summarizing")

      Ingestion::SummaryBuilder.new(product:).call
      summarize_reviews

      product.update!(ingestion_status: "ready", ingestion_error: nil)
      ingestion_run.update!(status: "ready", finished_at: Time.current)
    end

    def summarize_reviews
      ReviewAnalysis::BatchSummarizer.call(product:)
    rescue StandardError => error
      raise StandardError, SUMMARIZATION_FAILURE_MESSAGE % error.message
    end

    def mark_failed(error_message)
      product.update!(ingestion_status: "failed", ingestion_error: error_message)
      ingestion_run.update!(status: "failed", error: error_message, finished_at: Time.current)
    end

    def update_fetch_counters(metadata)
      ingestion_run.update!(
        raw_fetch_metadata: { fetch: metadata },
        pages_attempted: metadata[:pages_attempted].to_i,
        pages_succeeded: metadata[:pages_succeeded].to_i
      )
    end

    def probe(fetch_result)
      ReviewPlatforms::TrustpilotProbe.new(
        html: fetch_result.body,
        source_url: product.source_url,
        fetch_metadata: fetch_result.metadata
      ).call
    end

    def probe_warnings(probe_result)
      [
        (BLOCKED_WARNING if probe_result[:captcha_or_block_detected]),
        (THIN_CORPUS_WARNING if probe_result[:corpus_quality] == "thin")
      ].compact
    end

    def fetch_failure_message(error_code)
      return FETCH_BLOCKED_MESSAGE if error_code == "blocked"

      FETCH_FAILURE_MESSAGE % error_code
    end

    def update_product_metadata(html)
      metadata = adapter.parse_product_metadata(html)
      return if product.name.present? || metadata[:name].blank?

      product.update!(name: metadata[:name])
    end
end
