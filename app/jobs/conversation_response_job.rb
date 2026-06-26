class ConversationResponseJob < ApplicationJob
  def perform(conversation_id, content)
    conversation = Conversation.find(conversation_id)

    if conversation.product
      answer_product_question(conversation, content)
    else
      answer_generic_question(conversation, content)
    end
  end

  private
    def answer_product_question(conversation, content)
      conversation.chat_messages.create!(role: "user", content:)

      result = ReviewAnalysis::QuestionAnswerer.call(product: conversation.product, question: content)
      conversation.chat_messages.create!(
        role: "assistant",
        content: result.answer_markdown,
        content_raw: result.to_h
      )
    end

    def answer_generic_question(conversation, content)
      conversation.ask(content) do |chunk|
        next if chunk.content.blank?

        chat_message = conversation.chat_messages.last
        chat_message&.broadcast_append_chunk(chunk.content)
      end

      # Streaming appends escaped text chunks; re-render once so markdown renders.
      conversation.chat_messages.last&.broadcast_render_in_conversation
    end
end
