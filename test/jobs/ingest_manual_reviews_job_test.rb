require "test_helper"

class IngestManualReviewsJobTest < ActiveJob::TestCase
  test "parses uploaded CSV, dedupes, summarizes, and marks run ready" do
    product = Product.create!(import_mode: Product::PLATFORM_MANUAL_IMPORT, name: "Manual CRM")
    ingestion_run = product.ingestion_runs.create!
    ingestion_run.reviews_file.attach(
      io: StringIO.new(file_fixture("manual_reviews.csv").read),
      filename: "manual_reviews.csv",
      content_type: "text/csv"
    )

    with_fake_batch_summary_client do |client|
      assert_difference -> { Review.count }, 2 do
        assert_difference -> { InsightBatch.count }, 1 do
          IngestManualReviewsJob.perform_now(ingestion_run)
        end
      end

      assert_equal 1, client.calls.size
    end

    product.reload
    ingestion_run.reload

    assert_predicate product, :ready?
    assert_predicate ingestion_run, :ready?
    assert_equal 3, ingestion_run.reviews_found
    assert_equal 2, ingestion_run.reviews_imported
    assert_equal 1, ingestion_run.reviews_skipped
    assert_equal 2, product.reviews_count
    assert_equal 1, product.insight_batches.count
    assert_equal [
      "Billing was confusing and cancellation took too long.",
      "Setup was simple and support answered quickly."
    ], product.reviews.order(:body).pluck(:body)
    assert_nil product.source_url
  end

  test "fails clearly when uploaded file is empty" do
    product = Product.create!(import_mode: Product::PLATFORM_MANUAL_IMPORT, name: "Empty Manual")
    ingestion_run = product.ingestion_runs.create!
    ingestion_run.reviews_file.attach(
      io: StringIO.new("\n\n  \n\n"),
      filename: "empty.csv",
      content_type: "text/csv"
    )

    with_fake_batch_summary_client do
      assert_no_difference -> { Review.count } do
        IngestManualReviewsJob.perform_now(ingestion_run)
      end
    end

    product.reload
    ingestion_run.reload

    assert_predicate product, :failed?
    assert_predicate ingestion_run, :failed?
    assert_equal "The uploaded file is empty.", product.ingestion_error
    assert_equal "The uploaded file is empty.", ingestion_run.error
  end

  test "fails clearly when CSV has a body column but no usable rows" do
    product = Product.create!(import_mode: Product::PLATFORM_MANUAL_IMPORT, name: "No Rows")
    ingestion_run = product.ingestion_runs.create!
    ingestion_run.reviews_file.attach(
      io: StringIO.new("title,body\n,\n,"),
      filename: "header-only.csv",
      content_type: "text/csv"
    )

    with_fake_batch_summary_client do
      assert_no_difference -> { Review.count } do
        IngestManualReviewsJob.perform_now(ingestion_run)
      end
    end

    product.reload
    ingestion_run.reload

    assert_predicate product, :failed?
    assert_predicate ingestion_run, :failed?
    assert_equal "No reviews found in the CSV. Ensure it has a 'body' column with at least one non-empty review.", product.ingestion_error
    assert_equal "No reviews found in the CSV. Ensure it has a 'body' column with at least one non-empty review.", ingestion_run.error
  end

  test "fails when no file is attached" do
    product = Product.create!(import_mode: Product::PLATFORM_MANUAL_IMPORT, name: "No File")
    ingestion_run = product.ingestion_runs.create!

    IngestManualReviewsJob.perform_now(ingestion_run)

    product.reload
    ingestion_run.reload

    assert_predicate product, :failed?
    assert_predicate ingestion_run, :failed?
    assert_equal "No reviews file was attached to this ingestion run.", ingestion_run.error
  end
end
