require "test_helper"

class ConversationsFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @product = products(:ready)
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "conversation routes render generic screens without product binding" do
    get conversations_path
    assert_response :success
    assert_select "a", text: "AIModels", count: 0

    get new_conversation_path(product_id: @product.id)
    assert_response :success
    assert_select "input[name='conversation[product_id]']", count: 0
    assert_select "select[name='conversation[model]']", count: 0
  end

  test "generic conversation create enqueues generic response" do
    assert_enqueued_with(job: ConversationResponseJob) do
      assert_difference -> { Conversation.count }, 1 do
        post conversations_path, params: {
          conversation: { prompt: "What can you do?" }
        }
      end
    end

    conversation = Conversation.order(:created_at).last

    assert_nil conversation.product
    assert_redirected_to conversation_path(conversation)
  end

  test "conversation create with product id redirects to product without enqueueing" do
    assert_no_difference -> { Conversation.count } do
      assert_no_enqueued_jobs only: ConversationResponseJob do
        post conversations_path, params: {
          conversation: {
            product_id: @product.id,
            prompt: "What pain points appear in reviews?"
          }
        }
      end
    end

    assert_redirected_to product_path(@product)
  end

  test "message create enqueues response without performing live AI call" do
    conversation = Conversation.create!

    assert_enqueued_with(job: ConversationResponseJob, args: [ conversation.id, "What do users praise?" ]) do
      post conversation_chat_messages_path(conversation), params: {
        chat_message: { content: "What do users praise?" }
      }
    end

    assert_response :redirect
    assert_redirected_to conversation_path(conversation)
  end

  test "generic message route cannot mutate product conversations" do
    conversation = @product.conversation!

    assert_no_difference -> { conversation.chat_messages.count } do
      assert_no_enqueued_jobs only: ConversationResponseJob do
        post conversation_chat_messages_path(conversation), params: {
          chat_message: { content: "Bypass the product guard" }
        }
      end
    end

    assert_redirected_to product_path(@product)
  end

  test "product chat posts stay on product page and reuse one conversation" do
    assert_difference -> { @product.conversations.count }, 1 do
      assert_enqueued_with(job: ProductConversationResponseJob) do
        post product_chat_messages_path(@product),
          params: { question: "What pain points appear in reviews?" },
          as: :turbo_stream
      end
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_no_match %r{/conversations/}, response.location.to_s
    assert_includes response.body, "product_chat_form"
    assert_includes response.body, "What pain points appear in reviews?"
    assert_includes response.body, "product_chat_pending"
    assert_includes response.body, "Thinking..."
    assert_includes response.body, "disabled="
    refute_includes response.body, "Reading reviews..."

    assert_no_difference -> { @product.conversations.count } do
      assert_enqueued_with(job: ProductConversationResponseJob) do
        post product_chat_messages_path(@product),
          params: { question: "What do users praise?" },
          as: :turbo_stream
      end
    end
  end

  test "product chat post is disabled until reviews are queryable" do
    product = products(:example)
    product.update!(ingestion_status: "ready", reviews_count: product.reviews.count)

    assert_no_difference -> { product.conversations.count } do
      assert_no_enqueued_jobs only: ProductConversationResponseJob do
        post product_chat_messages_path(product),
          params: { question: "What pain points appear in reviews?" },
          as: :turbo_stream
      end
    end

    assert_redirected_to product_path(product)
  end

  test "product chat clear is disabled until reviews are queryable" do
    product = products(:example)
    product.update!(ingestion_status: "ready", reviews_count: product.reviews.count)

    assert_no_difference -> { product.conversations.count } do
      delete clear_product_chat_messages_path(product), as: :turbo_stream
    end

    assert_redirected_to product_path(product)
  end

  test "product chat clear deletes messages but keeps product conversation" do
    conversation = @product.conversation!
    conversation.chat_messages.create!(role: "user", content: "What do users praise?")
    conversation.chat_messages.create!(
      role: "assistant",
      content: "Users praise exports.",
      content_raw: { "supporting_review_ids" => [ reviews(:ready_exports).id.to_s ] }
    )

    assert_no_difference -> { Conversation.count } do
      assert_difference -> { conversation.chat_messages.reload.count }, -2 do
        delete clear_product_chat_messages_path(@product), as: :turbo_stream
      end
    end

    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
    assert_includes response.body, "product_chat_empty"
    assert_includes response.body, "Ask question about #{@product.display_name} reviews."
    assert_includes response.body, "product_chat_form"
    assert_includes response.body, "CLEAR"
    refute_includes response.body, "What do users praise?"
    assert_equal conversation, @product.reload.conversation
    assert_not_nil conversation.reload.cleared_at
  end

  test "product show renders user questions and assistant answers in product conversation" do
    conversation = @product.conversation!
    conversation.chat_messages.create!(role: "user", content: "What do users praise?")
    conversation.chat_messages.create!(
      role: "assistant",
      content: "**Users praise exports.**",
      content_raw: { "supporting_review_ids" => [ reviews(:ready_exports).id.to_s ], "confidence" => "high" }
    )

    get product_path(@product)

    assert_response :success
    assert_select "#chat_messages", text: /What do users praise?/
    assert_select "#chat_messages strong", text: "Users praise exports."
    assert_select "#chat_messages", text: /Supporting reviews: #{reviews(:ready_exports).id}/
    assert_select "#chat_messages", text: /Confidence:/, count: 0
    assert_select "button", text: "CLEAR"
  end
end
