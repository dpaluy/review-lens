require "application_system_test_case"

class ProductsTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  test "creates an ingestion run for a trustpilot product url" do
    visit root_path

    fill_in "Review platform URL", with: "https://www.trustpilot.com/review/quickbooks.intuit.com"
    click_on "Ingest Reviews"

    assert_text "quickbooks.intuit.com"
    assert_text "Trustpilot"
    assert_text "Ingestion status"
    assert_text "Pending"
    assert_text "Pages attempted"
    assert_text "Reviews found"
  end

  test "product chat disables ask while waiting for answer" do
    product = products(:ready)

    visit product_path(product)
    assert_no_text "Top pain points"
    assert_no_text "Try these blocked questions:"

    fill_in "question", with: "What do users praise?"
    assert_enqueued_with(job: ProductConversationResponseJob) do
      click_on "Ask"
      assert_text "Thinking..."
    end

    assert_text "What do users praise?"
    assert_selector "input[name='question']:disabled"
    assert_button "Ask", disabled: true
    assert_button "CLEAR", disabled: true
  end
end
