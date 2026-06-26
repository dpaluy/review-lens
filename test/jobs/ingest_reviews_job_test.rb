require "test_helper"

class IngestReviewsJobTest < ActiveJob::TestCase
  FetcherStub = Struct.new(:result) do
    def fetch(_source_url)
      result
    end
  end

  test "imports fetched Trustpilot fixture and marks run ready" do
    html = file_fixture("trustpilot_viable_corpus.html").read
    product = products(:missing_status_details)
    ingestion_run = ingestion_runs(:missing_status_details)

    client = nil

    with_fake_batch_summary_client do |fake_client|
      client = fake_client

      run_with_fetch_result(ingestion_run, successful_fetch_result(html)) do
        assert_changes -> { product.reload.ingestion_status }, to: "ready" do
          IngestReviewsJob.perform_now(ingestion_run)
        end
      end
    end

    ingestion_run.reload
    assert_predicate ingestion_run, :ready?
    assert_equal 1, ingestion_run.pages_attempted
    assert_equal 1, ingestion_run.pages_succeeded
    assert_equal 20, ingestion_run.reviews_found
    assert_equal 20, ingestion_run.reviews_imported
    assert_equal 0, ingestion_run.reviews_skipped
    assert_equal 20, product.reload.reviews_count
    assert_equal "trustpilot-html-v1", ingestion_run.parser_version
    assert_equal "viable", ingestion_run.raw_fetch_metadata.fetch("probe").fetch("corpus_quality")
    assert_equal 1, client.calls.size

    insight_batch = product.insight_batches.sole
    assert_equal 0, insight_batch.batch_index
    assert_equal 20, insight_batch.reviews_count
    assert_equal product.reviews.order(:id).pluck(:id), insight_batch.review_ids
    assert_equal insight_batch.review_ids.map(&:to_s), insight_batch.summary.fetch("supporting_review_ids")
  end

  test "fails clearly when batch summarization fails" do
    html = file_fixture("trustpilot_viable_corpus.html").read
    product = products(:missing_status_details)
    ingestion_run = ingestion_runs(:missing_status_details)
    client = nil

    with_fake_batch_summary_client(error: RuntimeError.new("AI unavailable")) do |fake_client|
      client = fake_client

      run_with_fetch_result(ingestion_run, successful_fetch_result(html)) do
        IngestReviewsJob.perform_now(ingestion_run)
      end
    end

    assert_predicate product.reload, :failed?
    assert_predicate ingestion_run.reload, :failed?
    assert_equal "Review summarization failed: AI unavailable", product.ingestion_error
    assert_equal "Review summarization failed: AI unavailable", ingestion_run.error
    assert_equal 20, product.reviews_count
    assert_empty product.insight_batches
    assert_equal 1, client.calls.size
  end

  test "fails clearly on fetch failure" do
    product = products(:missing_status_details)
    ingestion_run = ingestion_runs(:missing_status_details)

    run_with_fetch_result(ingestion_run, failed_fetch_result("timeout")) do
      IngestReviewsJob.perform_now(ingestion_run)
    end

    assert_predicate product.reload, :failed?
    assert_predicate ingestion_run.reload, :failed?
    assert_equal "Trustpilot fetch failed: timeout", product.ingestion_error
    assert_equal "Trustpilot fetch failed: timeout", ingestion_run.error
    assert_equal 1, ingestion_run.pages_attempted
    assert_equal 0, ingestion_run.pages_succeeded
    assert_empty product.reviews
  end

  test "records thin corpus parser warning" do
    html = file_fixture("trustpilot_thin_corpus.html").read
    product = products(:missing_status_details)
    ingestion_run = ingestion_runs(:missing_status_details)

    with_fake_batch_summary_client do
      run_with_fetch_result(ingestion_run, successful_fetch_result(html)) do
        IngestReviewsJob.perform_now(ingestion_run)
      end
    end

    assert_predicate product.reload, :ready?
    assert_includes ingestion_run.reload.warning_messages, IngestReviewsJob::THIN_CORPUS_WARNING
    assert_equal "thin", ingestion_run.raw_fetch_metadata.fetch("probe").fetch("corpus_quality")
    assert_equal 5, ingestion_run.reviews_imported
    assert_equal 1, product.insight_batches.count
  end

  test "records blocked parser warning and fails without reviews" do
    html = file_fixture("trustpilot_blocked_captcha.html").read
    product = products(:missing_status_details)
    ingestion_run = ingestion_runs(:missing_status_details)

    run_with_fetch_result(ingestion_run, successful_fetch_result(html)) do
      IngestReviewsJob.perform_now(ingestion_run)
    end

    assert_predicate product.reload, :failed?
    assert_predicate ingestion_run.reload, :failed?
    assert_includes ingestion_run.warning_messages, IngestReviewsJob::BLOCKED_WARNING
    assert_equal "blocked", ingestion_run.raw_fetch_metadata.fetch("probe").fetch("status")
    assert_equal IngestReviewsJob::NO_USABLE_REVIEWS_MESSAGE, ingestion_run.error
  end

  private
    def run_with_fetch_result(ingestion_run, result)
      product = ingestion_run.product
      product.reviews.destroy_all
      product.update!(ingestion_status: "pending", ingestion_error: nil, reviews_count: 0)
      ingestion_run.update!(
        status: "pending",
        error: nil,
        warnings: [],
        raw_fetch_metadata: {},
        pages_attempted: 0,
        pages_succeeded: 0,
        reviews_found: 0,
        reviews_imported: 0,
        reviews_skipped: 0
      )

      stub_fetcher(result) do
        yield
      end
    end

    def stub_fetcher(result)
      original_new = Ingestion::Fetcher.method(:new)
      Ingestion::Fetcher.define_singleton_method(:new) do |*_args, **_kwargs|
        FetcherStub.new(result)
      end

      yield
    ensure
      Ingestion::Fetcher.define_singleton_method(:new) do |*args, **kwargs|
        original_new.call(*args, **kwargs)
      end
    end

    def successful_fetch_result(html)
      Ingestion::Fetcher::Result.new(
        successful: true,
        body: html,
        metadata: {
          pages_attempted: 1,
          pages_succeeded: 1,
          final_url: "https://www.trustpilot.com/review/missing-status.example.com",
          html_bytes: html.bytesize,
          content_type: "text/html"
        },
        error_code: nil
      )
    end

    def failed_fetch_result(error_code)
      Ingestion::Fetcher::Result.new(
        successful: false,
        body: nil,
        metadata: {
          pages_attempted: 1,
          pages_succeeded: 0,
          final_url: "https://www.trustpilot.com/review/missing-status.example.com"
        },
        error_code:
      )
    end
end
