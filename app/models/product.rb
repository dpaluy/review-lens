class Product < ApplicationRecord
  has_many :ingestion_runs, dependent: :destroy
  has_many :reviews, dependent: :destroy

  enum :ingestion_status, {
    pending: "pending",
    fetching: "fetching",
    parsing: "parsing",
    summarizing: "summarizing",
    ready: "ready",
    failed: "failed"
  }

  validates :platform, :source_url, :external_id, presence: true
  validates :external_id, uniqueness: { scope: :platform }
end
