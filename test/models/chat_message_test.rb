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
end
