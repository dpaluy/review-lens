require "test_helper"

class ProductsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "creates product ingestion run trustpilot url" do
    assert_enqueued_jobs 1, only: IngestReviewsJob do
      assert_difference -> { Product.count }, 1 do
        assert_difference -> { IngestionRun.count }, 1 do
          post products_path, params: {
            product: { source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com" }
          }
        end
      end
    end

    product = Product.order(:created_at).last

    assert_redirected_to product_path(product)
    assert_equal "trustpilot", product.platform
    assert_equal "https://www.trustpilot.com/review/quickbooks.intuit.com", product.source_url
    assert_equal "quickbooks.intuit.com", product.external_id
    assert_predicate product, :pending?
    assert_predicate product.ingestion_runs.last, :pending?
  end

  test "reuses cached product by trustpilot review target" do
    post products_path, params: {
      product: { source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com" }
    }

    product = Product.find_by!(platform: "trustpilot", external_id: "quickbooks.intuit.com")

    assert_no_difference -> { Product.count } do
      assert_difference -> { product.ingestion_runs.reload.count }, 1 do
        post products_path, params: {
          product: { source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com?languages=all" }
        }
      end
    end

    assert_redirected_to product_path(product)
  end

  test "rejects unsupported hosts without creating records" do
    assert_no_difference -> { Product.count } do
      assert_no_difference -> { IngestionRun.count } do
        post products_path, params: {
          product: { source_url: "https://www.getapp.com/customer-management-software/a/hubspot-crm/" }
        }
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Source url must be Trustpilot URL"
    assert_not_includes response.body, "Platform can't be blank"
    assert_not_includes response.body, "External can't be blank"
  end

  test "rejects malformed urls without creating records" do
    assert_no_difference -> { Product.count } do
      assert_no_difference -> { IngestionRun.count } do
        post products_path, params: {
          product: { source_url: "not url" }
        }
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Source url must be valid URL"
    assert_not_includes response.body, "Platform can't be blank"
    assert_not_includes response.body, "External can't be blank"
  end

  test "creates manual import product and enqueues job from uploaded CSV" do
    file = fixture_file_upload("manual_reviews.csv", "text/csv")

    assert_enqueued_jobs 1, only: IngestManualReviewsJob do
      assert_difference -> { Product.count }, 1 do
        assert_difference -> { IngestionRun.count }, 1 do
          post products_path, params: {
            product: {
              import_mode: "manual",
              name: "Manual CRM",
              manual_file: file
            }
          }
        end
      end
    end

    product = Product.order(:created_at).last
    ingestion_run = product.ingestion_runs.last

    assert_redirected_to product_path(product)
    assert_equal "manual", product.platform
    assert_equal "Manual CRM", product.name
    assert_nil product.source_url
    assert_predicate product, :pending?
    assert_predicate ingestion_run, :pending?
    assert_predicate ingestion_run.reviews_file, :attached?
  end

  test "manual import rejects missing file without creating records" do
    assert_no_difference -> { Product.count } do
      assert_no_difference -> { IngestionRun.count } do
        post products_path, params: {
          product: {
            import_mode: "manual",
            name: "Empty Manual Import"
          }
        }
      end
    end

    assert_response :unprocessable_content
  end

  test "does not fake ingestion run status when run is missing" do
    get product_path(products(:manual))

    assert_response :not_found
  end

  test "shows pending ingestion status without blank spinner" do
    get product_path(products(:example))

    assert_response :success
    assert_select "h1", "Example"
    assert_no_match(/spinner/i, response.body)
    assert_select "[data-testid='parser-warnings']", false
    assert_select "[data-testid='thin-corpus-warning']", false
  end

  test "disables product chat until reviews are queryable" do
    product = products(:example)
    product.update!(ingestion_status: "ready", reviews_count: product.reviews.count)

    get product_path(product)

    assert_response :success
    assert_select "#product_chat_form", false
    assert_select "#chat_messages", false
    assert_select "p", "Q&A unlocks when reviews finish processing"
  end

  test "shows in progress ingestion counters and parser warnings" do
    get product_path(products(:fetching))

    assert_response :success
    assert_select "h1", "Fetching Example"
    assert_select "[data-testid='parser-warnings']" do
      assert_select "p", /Parser warnings/
      assert_select "li", "Second page returned no usable review cards"
    end
  end

  test "shows ready ingestion result counters" do
    get product_path(products(:ready))

    assert_response :success
    assert_select "h1", "Ready Example"
    assert_select "li", "One duplicate review was skipped"
  end

  test "shows failed ingestion error and warnings" do
    get product_path(products(:failed))

    assert_response :success
    assert_select "h1", "Failed Example"
    assert_select "[data-testid='failure-state'][role='alert']" do
      assert_select "p", /Ingestion failed/
      assert_select "p", "Fetch blocked by remote host"
    end
    assert_select "[data-testid='ingestion-step-pending'][data-state='done']"
    assert_select "[data-testid='ingestion-step-fetching'][data-state='failed']"
    assert_select "[data-testid='ingestion-step-parsing'][data-state='todo']"
    assert_select "li", "Trustpilot returned a blocking page before parsing"
  end

  test "shows parser failures on parsing step" do
    ingestion_runs(:failed).update!(
      pages_succeeded: 1,
      error: IngestReviewsJob::NO_USABLE_REVIEWS_MESSAGE
    )

    get product_path(products(:failed))

    assert_response :success
    assert_select "[data-testid='ingestion-step-pending'][data-state='done']"
    assert_select "[data-testid='ingestion-step-fetching'][data-state='done']"
    assert_select "[data-testid='ingestion-step-parsing'][data-state='failed']"
  end

  test "renders parser warnings on product status page" do
    product = products(:example)
    product.update_columns(ingestion_status: "ready", reviews_count: 25)
    ingestion_runs(:pending).update!(
      status: "ready",
      warnings: [
        { "code" => "missing_dates", "message" => "Review dates missing on 3 reviews." }
      ]
    )

    get product_path(product)

    assert_response :success
    assert_select "[data-testid='parser-warnings']" do
      assert_select "p", /Parser warnings/
      assert_select "li", "Review dates missing on 3 reviews."
    end
  end

  test "does not render parser warnings when warnings are empty" do
    product = products(:example)
    product.update_columns(ingestion_status: "ready", reviews_count: 20)
    ingestion_runs(:pending).update!(status: "ready", warnings: [])

    get product_path(product)

    assert_response :success
    assert_select "[data-testid='parser-warnings']", false
    assert_select "[data-testid='thin-corpus-warning']", false
  end

  test "renders thin review set warning as first class warning" do
    product = products(:example)
    product.update_columns(ingestion_status: "ready", reviews_count: 4)
    ingestion_runs(:pending).update!(status: "ready", warnings: [])

    get product_path(product)

    assert_response :success
    assert_select "[data-testid='thin-corpus-warning']" do
      assert_select "p", /Thin review set/
      assert_select "p", "Only 4 usable reviews available. ReviewLens needs least 20 usable reviews for grounded answers."
    end
    assert_select "[data-testid='parser-warnings']", false
  end
end
