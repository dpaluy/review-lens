require "test_helper"

class ManualImportFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "new page renders a file upload field for manual import" do
    get new_product_path

    assert_response :success
    assert_select "input[type=hidden][name='product[import_mode]']"
    assert_select "input[type=file][name='product[manual_file]']"
    assert_select "textarea[name='product[manual_reviews]']", false
    assert_select "input[name='product[source_url]']", count: 1
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
    assert_equal "manual_reviews.csv", ingestion_run.reviews_file.filename.to_s
  end

  test "accepts manual import without a name and derives it from the filename" do
    file = fixture_file_upload("manual_reviews.csv", "text/csv")

    assert_difference -> { Product.count }, 1 do
      post products_path, params: {
        product: {
          import_mode: "manual",
          manual_file: file
        }
      }
    end

    product = Product.order(:created_at).last

    assert_redirected_to product_path(product)
    assert_equal "Manual reviews", product.name
    assert_nil product.source_url
    assert_equal "Manual reviews", product.display_name
  end

  test "rejects manual import without a file" do
    assert_no_difference -> { Product.count } do
      assert_no_difference -> { IngestionRun.count } do
        post products_path, params: {
          product: {
            import_mode: "manual",
            name: "Missing File"
          }
        }
      end
    end

    assert_response :unprocessable_content
  end
end
