class ConversationResponseJob < ApplicationJob
  def perform(conversation_id, content)
    conversation = Conversation.find(conversation_id)

    conversation.ask(content) do |chunk|
      next if chunk.content.blank?

      chat_message = conversation.chat_messages.last
      chat_message&.broadcast_append_chunk(chunk.content)
    end

    # Streaming appends escaped text chunks; re-render once so markdown renders.
    conversation.chat_messages.last&.broadcast_render_in_conversation
  end
end
