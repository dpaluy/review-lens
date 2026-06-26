require "test_helper"

class IngestionRunTest < ActiveSupport::TestCase
  test "belongs to product and has status from fixture" do
    ingestion_run = ingestion_runs(:pending)

    assert_equal products(:example), ingestion_run.product
    assert_predicate ingestion_run, :pending?
  end

  test "normalizes stored warning shapes to display messages" do
    ingestion_run = ingestion_runs(:pending)
    ingestion_run.warnings = [
      "Trustpilot returned fewer review cards than expected.",
      { "code" => "missing_dates", "message" => "Review dates were missing." },
      { detail: "Reviewer roles were not visible." },
      {},
      nil
    ]

    assert_equal [
      "Trustpilot returned fewer review cards than expected.",
      "Review dates were missing.",
      "Reviewer roles were not visible."
    ], ingestion_run.warning_messages
  end
end
