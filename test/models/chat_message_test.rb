require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  setup do
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "allows empty assistant content for RubyLLM streaming persistence" do
    conversation = Conversation.create!(product: products(:ready))

    chat_message = conversation.chat_messages.create!(role: "assistant")

    assert_predicate chat_message, :persisted?
    assert_nil chat_message.content
  end

  test "renders user broadcast partial with chat_message local" do
    conversation = Conversation.create!(product: products(:ready))
    chat_message = conversation.chat_messages.create!(role: "user", content: "What do users praise?")

    html = ApplicationController.render(
      partial: "chat_messages/user",
      locals: { chat_message: }
    )

    assert_includes html, "What do users praise?"
  end

  test "renders assistant broadcast partial with chat_message local" do
    conversation = Conversation.create!(product: products(:ready))
    chat_message = conversation.chat_messages.create!(
      role: "assistant",
      content: "Users praise reliable automations.",
      content_raw: {
        "answer_status" => "answered",
        "confidence" => "high",
        "supporting_review_ids" => [ reviews(:ready_exports).id.to_s ]
      }
    )

    html = ApplicationController.render(
      partial: "chat_messages/assistant",
      locals: { chat_message: }
    )

    assert_includes html, "Users praise reliable automations."
    assert_includes html, "Confidence: high"
  end

  test "broadcast_render_in_conversation publishes a replace turbo stream with rendered markdown" do
    conversation = Conversation.create!(product: products(:ready))
    chat_message = conversation.chat_messages.create!(role: "assistant", content: "**bold answer**")

    chat_message.broadcast_render_in_conversation

    raw = broadcasts("conversation_#{conversation.id}").map { |m| JSON.parse(m) rescue m }.join
    assert_match(%r{action="replace" target="chat_message_#{chat_message.id}"}, raw)
    assert_includes raw, %(class="rl-markdown")
    assert_includes raw, "<strong>bold answer</strong>"
  end
end
