require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
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
end
