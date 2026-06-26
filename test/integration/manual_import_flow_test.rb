require "test_helper"

class ManualImportFlowTest < ActionDispatch::IntegrationTest
  test "creates manual import product from pasted review blocks" do
    get new_product_path

    assert_response :success
    assert_select "input[type=hidden][name='product[import_mode]']"
    assert_select "textarea[name='product[manual_reviews]']"

    pasted_reviews = <<~TEXT
      Setup simple and support answered quickly.


      Billing confusing cancellation took too long.

      Setup simple and support answered quickly.


    TEXT

    with_fake_batch_summary_client do |client|
      assert_difference -> { Product.count }, 1 do
        assert_difference -> { IngestionRun.count }, 1 do
          assert_difference -> { Review.count }, 2 do
            assert_difference -> { InsightBatch.count }, 1 do
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
      end

      assert_equal 1, client.calls.size
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
    assert_equal 1, product.insight_batches.count
    assert_equal [
      "Billing confusing cancellation took too long.",
      "Setup simple and support answered quickly."
    ], product.reviews.order(:body).pluck(:body)
  end

  test "fails clearly when manual import has no usable review blocks" do
    assert_difference -> { Product.count }, 1 do
      assert_difference -> { IngestionRun.count }, 1 do
        assert_no_difference -> { Review.count } do
          post products_path, params: {
            product: {
              import_mode: "manual",
              name: "Empty Manual Import",
              source_url: "https://example.com/empty",
              manual_reviews: "\n\n \n\n"
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
end
