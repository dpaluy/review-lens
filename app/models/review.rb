class Review < ApplicationRecord
  belongs_to :product, counter_cache: true

  enum :sentiment, {
    positive: "positive",
    neutral: "neutral",
    negative: "negative",
    unknown: "unknown"
  }

  before_validation :normalize_external_review_id
  before_validation :derive_sentiment_from_rating

  validates :content_hash, :body, presence: true
  validates :content_hash, uniqueness: { scope: :product_id }
  validates :external_review_id, uniqueness: { scope: :product_id }, allow_nil: true

  private

  def normalize_external_review_id
    self.external_review_id = nil if external_review_id.blank?
  end

  def derive_sentiment_from_rating
    self.sentiment =
      if rating.nil?
        "unknown"
      elsif rating >= 4
        "positive"
      elsif rating == 3
        "neutral"
      else
        "negative"
      end
  end
end
