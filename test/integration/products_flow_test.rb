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
    assert_includes response.body, "Source url must be a Trustpilot URL"
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
    assert_includes response.body, "Source url must be a valid URL"
    assert_not_includes response.body, "Platform can't be blank"
    assert_not_includes response.body, "External can't be blank"
  end

  test "does not fake ingestion run status when run is missing" do
    get product_path(products(:manual))

    assert_response :not_found
  end

  test "renders parser warnings on product status page" do
    product = products(:example)
    product.update_columns(ingestion_status: "ready", reviews_count: 25)
    ingestion_runs(:pending).update!(
      status: "ready",
      warnings: [
        { "code" => "missing_dates", "message" => "Review dates were missing on 3 reviews." }
      ]
    )

    get product_path(product)

    assert_response :success
    assert_select "[data-testid='parser-warnings']" do
      assert_select "h2", "Parser warnings"
      assert_select "li", "Review dates were missing on 3 reviews."
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
      assert_select "p", "Only 4 usable reviews are available. ReviewLens needs at least 20 usable reviews for grounded answers."
    end
    assert_select "[data-testid='parser-warnings']", false
  end
end
