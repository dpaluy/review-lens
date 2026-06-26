class IngestionRun < ApplicationRecord
  belongs_to :product

  WARNING_MESSAGE_KEYS = %w[ message detail title code ].freeze

  enum :status, {
    pending: "pending",
    fetching: "fetching",
    parsing: "parsing",
    summarizing: "summarizing",
    ready: "ready",
    failed: "failed"
  }

  def warning_messages
    Array(warnings).filter_map do |warning|
      case warning
      when String
        warning.presence
      when Hash
        WARNING_MESSAGE_KEYS.filter_map { |key| warning[key].presence || warning[key.to_sym].presence }.first
      end
    end
  end
end
