require "test_helper"

class ChatMessageTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "allows empty assistant content RubyLLM streaming persistence" do
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
      content: "**Billing clarity (235)**\n\nUsers praise reliable automations.",
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

    assert_includes html, "<strong>Billing clarity (235)</strong>"
    refute_includes html, "**Billing clarity (235)**"
    assert_includes html, "Users praise reliable automations."
    assert_includes html, "Supporting reviews: #{reviews(:ready_exports).id}"
    refute_includes html, "Status:"
    refute_includes html, "Confidence:"
    refute_includes html, "Limitations:"
    refute_includes html, "Blocked category:"
  end

  test "assistant markdown renderer escapes unsafe html" do
    conversation = Conversation.create!(product: products(:ready))
    chat_message = conversation.chat_messages.create!(
      role: "assistant",
      content: "**Safe** <script>alert('xss')</script>"
    )

    html = ApplicationController.render(
      partial: "chat_messages/assistant",
      locals: { chat_message: }
    )

    assert_includes html, "<strong>Safe</strong>"
    refute_includes html, "<script>"
  end

  test "broadcasts messages on generic conversation stream" do
    conversation = Conversation.create!

    broadcasts = capture_broadcasts("conversation_#{conversation.id}") do
      conversation.chat_messages.create!(role: "user", content: "What do users praise?")
    end

    assert broadcasts.any? { |message| message.to_s.include?("What do users praise?") }
  end

  test "broadcast_render_in_conversation publishes replace turbo stream with rendered markdown" do
    conversation = Conversation.create!
    chat_message = conversation.chat_messages.create!(role: "assistant", content: "**bold answer**")

    chat_message.broadcast_render_in_conversation

    raw = broadcasts("conversation_#{conversation.id}").map { |message| JSON.parse(message) rescue message }.join
    assert_match(%r{action="replace" target="chat_message_#{chat_message.id}"}, raw)
    assert_includes raw, %(class="rl-markdown")
    assert_includes raw, "<strong>bold answer</strong>"
  end
end
