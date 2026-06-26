require "test_helper"

class IngestionRunTest < ActiveSupport::TestCase
  test "belongs to product and exposes status fixture" do
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

  test "warning messages are safe for nil and empty warnings" do
    ingestion_run = ingestion_runs(:pending)

    ingestion_run.warnings = nil
    assert_empty ingestion_run.warning_messages

    ingestion_run.warnings = []
    assert_empty ingestion_run.warning_messages
  end
end
