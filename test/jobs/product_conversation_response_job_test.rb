require "test_helper"

class ProductConversationResponseJobTest < ActiveJob::TestCase
  include ActionCable::TestHelper

  setup do
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "persists user question assistant answer and review metadata" do
    conversation = Conversation.create!(product: products(:ready))
    result = answer_result("Billing support is main issue.", reviews(:ready_billing).id.to_s)

    with_question_answerer(result) do
      ProductConversationResponseJob.perform_now(conversation.id, "What billing problems appear?")
    end

    messages = conversation.chat_messages.order(:created_at)
    assert_equal [ "user", "assistant" ], messages.pluck(:role)
    assert_equal "What billing problems appear?", messages.first.content
    assert_equal "Billing support is main issue.", messages.second.content
    assert_equal "high", messages.second.content_raw.fetch("confidence")
    assert_equal [ reviews(:ready_billing).id.to_s ], messages.second.content_raw.fetch("supporting_review_ids")
    assert_equal "answered", messages.second.content_raw.fetch("answer_status")
  end

  test "broadcasts product answers on product chat stream" do
    conversation = Conversation.create!(product: products(:ready))
    result = answer_result("Users praise reliable automations.", reviews(:ready_exports).id.to_s)

    broadcasts = capture_broadcasts(ProductChatBroadcaster.stream_for(conversation)) do
      with_question_answerer(result) do
        ProductConversationResponseJob.perform_now(conversation.id, "What do users praise?")
      end
    end

    raw = broadcasts.map { |message| JSON.parse(message) rescue message }.join
    assert_includes raw, "product_chat_pending"
    assert_includes raw, "product_chat_form"
    assert_includes raw, "Users praise reliable automations."
  end

  test "skips prompts cleared before job starts" do
    conversation = Conversation.create!(product: products(:ready), cleared_at: Time.current)

    assert_no_difference -> { conversation.chat_messages.count } do
      ProductConversationResponseJob.perform_now(conversation.id, "What billing problems appear?", 1.minute.ago)
    end
  end

  test "skips assistant answer when cleared while answering" do
    conversation = Conversation.create!(product: products(:ready))
    submitted_at = Time.current
    result = answer_result("Billing support is the main issue.", reviews(:ready_billing).id.to_s)

    with_question_answerer(result) do
      ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) do |**_kwargs|
        conversation.chat_messages.destroy_all
        conversation.update!(cleared_at: Time.current)
        result
      end
      ProductConversationResponseJob.perform_now(conversation.id, "What billing problems appear?", submitted_at)
    end

    assert_empty conversation.chat_messages.reload
  end

  test "replaces pending state with failure message when answer generation times out" do
    conversation = Conversation.create!(product: products(:ready))

    with_question_answerer_timeout do
      ProductConversationResponseJob.perform_now(conversation.id, "What billing problems appear?")
    end

    messages = conversation.chat_messages.order(:created_at)
    assert_equal [ "user", "assistant" ], messages.pluck(:role)
    assert_equal "I couldn't answer that. Please try again.", messages.second.content
    assert_equal "failed", messages.second.content_raw.fetch("answer_status")
    assert_empty messages.second.content_raw.fetch("supporting_review_ids")
  end

  test "does not broadcast assistant cleared after persistence" do
    conversation = Conversation.create!(product: products(:ready))
    submitted_at = 1.second.ago
    assistant = conversation.chat_messages.create!(role: "assistant", content: "Stale answer")
    conversation.chat_messages.destroy_all
    conversation.update!(cleared_at: Time.current)

    broadcasts = capture_broadcasts(ProductChatBroadcaster.stream_for(conversation)) do
      ProductConversationResponseJob.new.send(:broadcast_assistant_unless_cleared, conversation, assistant, submitted_at)
    end

    assert_empty broadcasts
  end

  test "unexpected answerer errors remain visible" do
    conversation = Conversation.create!(product: products(:ready))

    with_unexpected_question_answerer_error do
      assert_raises(RuntimeError) do
        ProductConversationResponseJob.perform_now(conversation.id, "What billing problems appear?")
      end
    end
  end

  test "blocked product questions refuse through product chat persistence path" do
    conversation = Conversation.create!(product: products(:ready))

    ProductConversationResponseJob.perform_now(conversation.id, "What is current weather?")

    assistant = conversation.chat_messages.order(:created_at).last
    assert_equal "assistant", assistant.role
    assert_equal "refused", assistant.content_raw.fetch("answer_status")
    assert_equal "outside_knowledge", assistant.content_raw.fetch("blocked_category")
    assert_includes assistant.content, "Trustpilot"
  end

  private

  def answer_result(markdown, review_id)
    ReviewAnalysis::QuestionAnswerer::Result.new(
      answer_markdown: markdown,
      confidence: "high",
      supporting_review_ids: [ review_id ],
      limitations: [],
      answer_status: "answered",
      blocked_category: nil,
      reason: nil
    )
  end

  def with_question_answerer(result)
    original_call = ReviewAnalysis::QuestionAnswerer.method(:call)
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**_kwargs| result }
    yield
  ensure
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**kwargs| original_call.call(**kwargs) }
  end

  def with_question_answerer_timeout
    original_call = ReviewAnalysis::QuestionAnswerer.method(:call)
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**_kwargs| raise Timeout::Error, "timeout" }
    yield
  ensure
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**kwargs| original_call.call(**kwargs) }
  end

  def with_unexpected_question_answerer_error
    original_call = ReviewAnalysis::QuestionAnswerer.method(:call)
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**_kwargs| raise "programmer error" }
    yield
  ensure
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**kwargs| original_call.call(**kwargs) }
  end
end
