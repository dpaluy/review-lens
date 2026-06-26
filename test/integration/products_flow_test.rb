require "test_helper"

class ProductsFlowTest < ActionDispatch::IntegrationTest
  test "creates product ingestion run trustpilot url" do
    assert_difference -> { Product.count }, 1 do
      assert_difference -> { IngestionRun.count }, 1 do
        post products_path, params: {
          product: { source_url: "https://www.trustpilot.com/review/quickbooks.intuit.com" }
        }
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

  test "creates manual import product with pasted review blocks" do
    pasted_reviews = <<~TEXT
      Setup was simple and support answered quickly.


      Billing was confusing and cancellation took too long.

      Setup was simple and support answered quickly.

    TEXT

    assert_difference -> { Product.count }, 1 do
      assert_difference -> { IngestionRun.count }, 1 do
        assert_difference -> { Review.count }, 2 do
          post products_path, params: {
            product: {
              import_mode: "manual",
              name: "Manual CRM",
              source_url: "https://example.com/manual-crm-reviews",
              manual_reviews: pasted_reviews
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
    assert_equal "https://example.com/manual-crm-reviews", product.source_url
    assert_predicate product, :ready?
    assert_predicate ingestion_run, :ready?
    assert_equal 3, ingestion_run.reviews_found
    assert_equal 2, ingestion_run.reviews_imported
    assert_equal 1, ingestion_run.reviews_skipped
    assert_equal 2, product.reviews_count
    assert_equal [
      "Billing was confusing and cancellation took too long.",
      "Setup was simple and support answered quickly."
    ], product.reviews.order(:body).pluck(:body)
  end

  test "manual import skips empty blocks and fails clearly without reviews" do
    assert_difference -> { Product.count }, 1 do
      assert_difference -> { IngestionRun.count }, 1 do
        assert_no_difference -> { Review.count } do
          post products_path, params: {
            product: {
              import_mode: "manual",
              name: "Empty Manual Import",
              source_url: "https://example.com/empty",
              manual_reviews: "\n\n  \n\n"
            }
          }
        end
      end
    end

    product = Product.order(:created_at).last
    ingestion_run = product.ingestion_runs.last

    assert_redirected_to product_path(product)
    assert_predicate product, :failed?
    assert_predicate ingestion_run, :failed?
    assert_equal "No usable manual review blocks were provided.", product.ingestion_error
    assert_equal "No usable manual review blocks were provided.", ingestion_run.error
  end

  test "does not fake ingestion run status when run is missing" do
    get product_path(products(:manual))

    assert_response :not_found
  end

  test "shows pending ingestion status without blank spinner" do
    get product_path(products(:example))

    assert_response :success
    assert_select "h1", "Example"
    assert_select "dt", "Platform"
    assert_select "dd", "trustpilot"
    assert_select "dt", "Source URL"
    assert_select "dd", "https://www.trustpilot.com/review/example.com"
    assert_select "dt", "Product status"
    assert_select "dd", "pending"
    assert_select "dt", "Run status"
    assert_select "dd", "pending"
    assert_select "dt", "Usable reviews"
    assert_select "dd", "4"
    assert_select "dt", "Pages attempted"
    assert_select "dd", "0"
    assert_select "dt", "Reviews found"
    assert_select "dd", "0"
    assert_select "dt", "Reviews imported"
    assert_select "dd", "0"
    assert_select "dt", "Reviews skipped"
    assert_select "dd", "0"
    assert_no_match(/spinner/i, response.body)
    assert_select "[data-testid='parser-warnings']", false
    assert_select "[data-testid='thin-corpus-warning']", false
  end

  test "shows in progress ingestion counters and parser warnings" do
    get product_path(products(:fetching))

    assert_response :success
    assert_select "h1", "Fetching Example"
    assert_select "dd", "fetching"
    assert_select "dt", "Pages attempted"
    assert_select "dd", "2"
    assert_select "dt", "Reviews found"
    assert_select "dd", "8"
    assert_select "[data-testid='parser-warnings']" do
      assert_select "h2", "Parser warnings"
      assert_select "li", "Second page returned no usable review cards"
    end
  end

  test "shows ready ingestion result counters" do
    get product_path(products(:ready))

    assert_response :success
    assert_select "h1", "Ready Example"
    assert_select "dd", "ready"
    assert_select "dt", "Pages attempted"
    assert_select "dd", "4"
    assert_select "dt", "Reviews found"
    assert_select "dd", "25"
    assert_select "dt", "Reviews imported"
    assert_select "dd", "24"
    assert_select "dt", "Reviews skipped"
    assert_select "dd", "1"
    assert_select "li", "One duplicate review was skipped"
  end

  test "shows failed ingestion error and warnings" do
    get product_path(products(:failed))

    assert_response :success
    assert_select "h1", "Failed Example"
    assert_select "dd", "failed"
    assert_select "h2", "Failure"
    assert_select "p", "Fetch blocked by remote host"
    assert_select "li", "Trustpilot returned a blocking page before parsing"
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
      assert_select "h2", "Parser warnings"
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

  test "renders thin corpus warning as first class warning" do
    product = products(:example)
    product.update_columns(ingestion_status: "ready", reviews_count: 4)
    ingestion_runs(:pending).update!(status: "ready", warnings: [])

    get product_path(product)

    assert_response :success
    assert_select "[data-testid='thin-corpus-warning']" do
      assert_select "h2", "Thin corpus"
      assert_select "p", "Only 4 usable reviews available. ReviewLens needs least 20 usable reviews for grounded answers."
    end
    assert_select "[data-testid='parser-warnings']", false
  end
end
