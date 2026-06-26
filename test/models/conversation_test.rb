require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  setup do
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "loads RubyLLM associations" do
    conversation = Conversation.create!(product: products(:ready))

    chat_message = conversation.chat_messages.create!(role: "user", content: "What do reviewers dislike?")

    assert_equal products(:ready), conversation.product
    assert_equal conversation, chat_message.conversation
    assert_kind_of ActiveRecord::Associations::CollectionProxy, conversation.chat_messages
  end

  test "allows only one conversation per product" do
    Conversation.create!(product: products(:ready))

    duplicate = Conversation.new(product: products(:ready))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_id], "has already been taken"
  end
end
