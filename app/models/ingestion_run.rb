class IngestionRun < ApplicationRecord
  belongs_to :product

  enum :status, {
    pending: "pending",
    fetching: "fetching",
    parsing: "parsing",
    summarizing: "summarizing",
    ready: "ready",
    failed: "failed"
  }
end
