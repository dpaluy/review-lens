require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  test "creates an ingestion run for a trustpilot product url" do
    visit root_path

    fill_in "Review platform URL", with: "https://www.trustpilot.com/review/quickbooks.intuit.com"
    click_on "Ingest Reviews"

    assert_text "quickbooks.intuit.com"
    assert_text "Platform"
    assert_text "trustpilot"
    assert_text "Product status"
    assert_text "Run status"
    assert_text "pending"
    assert_text "Pages attempted"
    assert_text "Reviews found"
  end
end
