class IngestionRun < ApplicationRecord
  WARNING_MESSAGE_KEYS = %w[message detail title code].freeze

  belongs_to :product

  enum :status, {
    pending: "pending",
    fetching: "fetching",
    parsing: "parsing",
    summarizing: "summarizing",
    ready: "ready",
    failed: "failed"
  }

  def self.warning_message_for(warning)
    case warning
    when String
      warning.presence
    when Hash
      WARNING_MESSAGE_KEYS.filter_map do |key|
        warning[key].presence || warning[key.to_sym].presence
      end.first
    end
  end

  def warning_messages
    Array(warnings).filter_map { |warning| self.class.warning_message_for(warning) }
  end
end
