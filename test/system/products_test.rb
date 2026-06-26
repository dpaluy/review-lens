require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  test "creates an ingestion run for a getapp product url" do
    visit root_path

    fill_in "Review platform URL", with: "https://www.getapp.com/customer-management-software/a/hubspot-crm/"
    click_on "Ingest Reviews"

    assert_text "hubspot-crm"
    assert_text "Platform"
    assert_text "getapp"
    assert_text "Status"
    assert_text "pending"
    assert_text "Ingestion run"
  end
end
