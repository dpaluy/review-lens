class ProductConversationResponseJob < ApplicationJob
  ANSWER_GENERATION_ERRORS = [
    Timeout::Error,
    (Net::OpenTimeout if defined?(Net::OpenTimeout)),
    (Net::ReadTimeout if defined?(Net::ReadTimeout)),
    (RubyLLM::Error if defined?(RubyLLM::Error))
  ].compact.freeze

  def perform(conversation_id, content, submitted_at = nil, user_message_id = nil)
    conversation = Conversation.find(conversation_id)
    return unless conversation.product

    answer_product_question(conversation, content, submitted_at, user_message_id)
  end

  private

  def answer_product_question(conversation, content, submitted_at, user_message_id)
    return if cleared_after_submission?(conversation, submitted_at)

    if user_message_id
      return unless conversation.chat_messages.exists?(user_message_id)
    else
      conversation.chat_messages.create!(role: "user", content:)
    end

    assistant = persist_answer(conversation, content, submitted_at)
  rescue *ANSWER_GENERATION_ERRORS => error
    Rails.logger.warn("Product conversation response failed: #{error.class}: #{error.message}")

    assistant = persist_failure(conversation, submitted_at)
  ensure
    broadcast_assistant_unless_cleared(conversation, assistant, submitted_at)
  end

  def persist_answer(conversation, content, submitted_at)
    result = ReviewAnalysis::QuestionAnswerer.call(product: conversation.product, question: content)

    conversation.with_lock do
      return if cleared_after_submission?(conversation, submitted_at)

      conversation.chat_messages.create!(
        role: "assistant",
        content: result.answer_markdown,
        content_raw: result.to_h
      )
    end
  end

  def persist_failure(conversation, submitted_at)
    conversation.with_lock do
      return if cleared_after_submission?(conversation, submitted_at)

      conversation.chat_messages.create!(
        role: "assistant",
        content: "I couldn't answer that. Please try again.",
        content_raw: { "answer_status" => "failed", "supporting_review_ids" => [] }
      )
    end
  end

  def cleared_after_submission?(conversation, submitted_at)
    return conversation.cleared_at.present? unless submitted_at

    conversation.cleared_at.present? && conversation.cleared_at >= submitted_at
  end

  def broadcast_assistant_unless_cleared(conversation, assistant, submitted_at)
    return unless assistant

    conversation.reload
    return if cleared_after_submission?(conversation, submitted_at)
    return unless conversation.chat_messages.exists?(assistant.id)

    ProductChatBroadcaster.assistant_created(assistant)
  end
end
