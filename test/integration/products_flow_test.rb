require "test_helper"

class ProductsFlowTest < ActionDispatch::IntegrationTest
  test "creates product and ingestion run for getapp url" do
    assert_difference -> { Product.count }, 1 do
      assert_difference -> { IngestionRun.count }, 1 do
        post products_path, params: {
          product: { source_url: "https://www.getapp.com/customer-management-software/a/hubspot-crm/" }
        }
      end
    end

    product = Product.order(:created_at).last

    assert_redirected_to product_path(product)
    assert_equal "getapp", product.platform
    assert_equal "https://www.getapp.com/customer-management-software/a/hubspot-crm/", product.source_url
    assert_equal "hubspot-crm", product.external_id
    assert_predicate product, :pending?
    assert_predicate product.ingestion_runs.last, :pending?
  end

  test "reuses cached product by getapp slug" do
    post products_path, params: {
      product: { source_url: "https://www.getapp.com/customer-management-software/a/hubspot-crm/" }
    }

    product = Product.find_by!(platform: "getapp", external_id: "hubspot-crm")

    assert_no_difference -> { Product.count } do
      assert_difference -> { product.ingestion_runs.reload.count }, 1 do
        post products_path, params: {
          product: { source_url: "https://www.getapp.com/sales-software/a/hubspot-crm/" }
        }
      end
    end

    assert_redirected_to product_path(product)
  end

  test "rejects unsupported hosts without creating records" do
    assert_no_difference -> { Product.count } do
      assert_no_difference -> { IngestionRun.count } do
        post products_path, params: {
          product: { source_url: "https://www.trustpilot.com/review/example.com" }
        }
      end
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Source url must be a GetApp URL"
    assert_not_includes response.body, "Platform can't be blank"
    assert_not_includes response.body, "External can't be blank"
  end

  test "rejects malformed urls without creating records" do
    assert_no_difference -> { Product.count } do
      assert_no_difference -> { IngestionRun.count } do
        post products_path, params: {
          product: { source_url: "not a url" }
        }
      end
    end

    assert_response :unprocessable_content
  end

  test "does not fake ingestion run status when run is missing" do
    get product_path(products(:manual))

    assert_response :not_found
  end
end
