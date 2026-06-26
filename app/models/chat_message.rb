class ChatMessage < ApplicationRecord
  acts_as_message chat: :conversation, model: :ai_model, model_class: "AIModel"

  has_many_attached :attachments

  broadcasts_to ->(chat_message) { "conversation_#{chat_message.conversation_id}" }, inserts_by: :append

  def answer_metadata
    content_raw.is_a?(Hash) ? content_raw : {}
  end

  def broadcast_append_chunk(content)
    broadcast_append_to "conversation_#{conversation_id}",
      target: "chat_message_#{id}_content",
      content: ERB::Util.html_escape(content.to_s)
  end

  # After RubyLLM finishes streaming, the assistant message is persisted via an
  # update, so the create-time append broadcast never fires. Re-render the whole
  # message container so the streamed (escaped) text is replaced with proper
  # markdown rendering. Rendered via #to_partial_path -> chat_messages/_assistant.
  def broadcast_render_in_conversation
    broadcast_replace_to "conversation_#{conversation_id}",
      target: "chat_message_#{id}",
      partial: to_partial_path,
      locals: { chat_message: self }
  end
end
