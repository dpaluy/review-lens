class Conversation < ApplicationRecord
  acts_as_chat messages: :chat_messages, model: :ai_model, model_class: "AIModel"

  belongs_to :product, optional: true
end
