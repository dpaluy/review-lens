class Product < ApplicationRecord
  SUPPORTED_PLATFORM = "trustpilot"
  SUPPORTED_HOSTS = %w[ trustpilot.com www.trustpilot.com ].freeze
  MINIMUM_USABLE_REVIEW_COUNT = 20

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

  before_validation :set_source_identity

  validates :source_url, presence: true
  validates :platform, :external_id, presence: true, if: :supported_source_uri?
  validates :external_id, uniqueness: { scope: :platform }, allow_nil: true
  validate :source_url_is_supported

  def thin_corpus?
    ready? && usable_review_count < MINIMUM_USABLE_REVIEW_COUNT
  end

  def usable_review_count
    reviews_count.to_i
  end

  def self.find_or_initialize_from_source_url(source_url)
    identity = source_identity(source_url)

    unless identity
      return new(source_url:).tap(&:valid?)
    end

    find_or_initialize_by(platform: SUPPORTED_PLATFORM, external_id: identity[:external_id]).tap do |product|
      product.source_url = identity[:source_url] if product.new_record?
    end
  end

  def self.source_identity(source_url)
    normalized_source_url = source_url.to_s.strip
    source_uri = parse_source_uri(normalized_source_url)
    slug = product_slug(source_uri)

    return unless source_uri.is_a?(URI::HTTP) && SUPPORTED_HOSTS.include?(source_uri.host.to_s.downcase) && slug.present?

    { source_url: normalized_source_url, external_id: slug }
  end

  private
    def self.parse_source_uri(source_url)
      URI.parse(source_url)
    rescue URI::InvalidURIError
      nil
    end

    def self.product_slug(source_uri)
      return unless source_uri

      segments = source_uri.path.split("/").reject(&:blank?)
      segments[1] if segments.first == "review"
    end

    def set_source_identity
      self.source_url = source_url.to_s.strip
      @source_uri = nil

      identity = self.class.source_identity(source_url)

      return unless identity

      self.platform = SUPPORTED_PLATFORM
      self.external_id = identity[:external_id]
    end

    def source_url_is_supported
      if source_uri.blank? || source_uri.host.blank?
        errors.add :source_url, "must be a valid URL"
      elsif !source_uri.is_a?(URI::HTTP)
        errors.add :source_url, "must be HTTP or HTTPS"
      elsif !SUPPORTED_HOSTS.include?(source_uri.host.downcase)
        errors.add :source_url, "must be a Trustpilot URL"
      elsif self.class.product_slug(source_uri).blank?
        errors.add :source_url, "must include a Trustpilot review target"
      end
    end

    def supported_source_uri?
      self.class.source_identity(source_url).present?
    end

    def source_uri
      @source_uri ||= self.class.parse_source_uri(source_url.to_s)
    end
end
