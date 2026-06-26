class IngestManualReviewsJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(ingestion_run)
    Ingestion::ManualImport.new(
      product: ingestion_run.product,
      ingestion_run:
    ).call
  end
end
