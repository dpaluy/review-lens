require "test_helper"

class IngestionRunTest < ActiveSupport::TestCase
  test "belongs to product and has status from fixture" do
    ingestion_run = ingestion_runs(:pending)

    assert_equal products(:example), ingestion_run.product
    assert_predicate ingestion_run, :pending?
  end
end
