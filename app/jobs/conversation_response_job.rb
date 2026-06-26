class ConversationResponseJob < ApplicationJob
  def perform(conversation_id, content)
    conversation = Conversation.find(conversation_id)

    conversation.ask(content) do |chunk|
      if chunk.content && !chunk.content.empty?
        chat_message = conversation.chat_messages.last
        chat_message.broadcast_append_chunk(chunk.content)
      end
    end
  end
end
