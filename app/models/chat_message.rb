class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation, model: :ai_model, model_class: "AIModel"
  has_many_attached :attachments

  broadcasts_to ->(chat_message) { "conversation_#{chat_message.conversation_id}" }, inserts_by: :append

  def broadcast_append_chunk(content)
    broadcast_append_to "conversation_#{conversation_id}",
      target: "chat_message_#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end
end
