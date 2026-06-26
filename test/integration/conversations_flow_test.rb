require "test_helper"

class ConversationsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @product = products(:ready)
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "conversation routes render generated screens" do
    get conversations_path
    assert_response :success
    assert_select "a", text: "AIModels", count: 0

    get new_conversation_path(product_id: @product.id)
    assert_response :success
    assert_select "input[name='conversation[product_id]'][value=?]", @product.id.to_s
    assert_select "select[name='conversation[model]']", count: 0
  end

  test "creates product-associated conversation and enqueues response" do
    assert_enqueued_with(job: ConversationResponseJob) do
      assert_difference -> { Conversation.count }, 1 do
        post conversations_path, params: {
          conversation: {
            product_id: @product.id,
            prompt: "What pain points appear in the reviews?"
          }
        }
      end
    end

    conversation = Conversation.order(:created_at).last
    assert_equal @product, conversation.product
    assert_redirected_to conversation_path(conversation)
  end

  test "message create enqueues response without performing live AI call" do
    conversation = Conversation.create!(product: @product)

    assert_enqueued_with(job: ConversationResponseJob, args: [ conversation.id, "What do users praise?" ]) do
      post conversation_chat_messages_path(conversation), params: {
        chat_message: { content: "What do users praise?" }
      }
    end

    assert_response :redirect
    assert_redirected_to conversation_path(conversation)
  end
end
