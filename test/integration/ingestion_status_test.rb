require "test_helper"

class IngestionStatusTest < ActionDispatch::IntegrationTest
  test "shows platform source statuses and counters when present" do
    get product_path(products(:ready))

    assert_response :success
    assert_select "h1", "Ready Example"
    assert_select "dt", "Platform"
    assert_select "dd", "trustpilot"
    assert_select "dt", "Source URL"
    assert_select "dd", "https://www.trustpilot.com/review/ready.example.com"
    assert_select "dt", "Product status"
    assert_select "dd", "ready"
    assert_select "dt", "Run status"
    assert_select "dd", "ready"
    assert_select "dt", "Usable reviews"
    assert_select "dd", "24"
    assert_select "dt", "Pages attempted"
    assert_select "dd", "4"
    assert_select "dt", "Pages succeeded"
    assert_select "dd", "4"
    assert_select "dt", "Reviews found"
    assert_select "dd", "25"
    assert_select "dt", "Reviews imported"
    assert_select "dd", "24"
    assert_select "dt", "Reviews skipped"
    assert_select "dd", "1"
  end

  test "shows parser warnings prominently when present" do
    get product_path(products(:fetching))

    assert_response :success
    assert_select "[data-testid='parser-warnings'][role='alert']" do
      assert_select "h2", "Parser warnings"
      assert_select "li", "Second page returned no usable review cards"
    end
  end

  test "shows thin corpus warning for ready products with fewer than twenty usable reviews" do
    get product_path(products(:thin_corpus))

    assert_response :success
    assert_select "[data-testid='thin-corpus-warning'][role='alert']" do
      assert_select "h2", "Thin corpus"
      assert_select "p", "Only 4 usable reviews available. ReviewLens needs least 20 usable reviews for grounded answers."
    end
  end

  test "shows failure state with clear error" do
    get product_path(products(:failed))

    assert_response :success
    assert_select "[data-testid='failure-state'][role='alert']" do
      assert_select "h2", "Failure"
      assert_select "p", "Fetch blocked by remote host"
    end
  end

  test "does not break when counters and warnings are missing" do
    get product_path(products(:missing_status_details))

    assert_response :success
    assert_select "h1", "Missing Status Details"
    assert_select "dt", "Pages attempted"
    assert_select "dd", "0"
    assert_select "[data-testid='parser-warnings']", false
    assert_select "[data-testid='thin-corpus-warning']", false
    assert_select "[data-testid='failure-state']", false
  end
end
