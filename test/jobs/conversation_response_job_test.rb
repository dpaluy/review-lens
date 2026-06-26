require "test_helper"

class ConversationResponseJobTest < ActiveJob::TestCase
  setup do
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "product conversations persist user question assistant answer and review metadata" do
    conversation = Conversation.create!(product: products(:ready))
    result = ReviewAnalysis::QuestionAnswerer::Result.new(
      answer_markdown: "Billing support is the main issue.",
      confidence: "high",
      supporting_review_ids: [ reviews(:ready_billing).id.to_s ],
      limitations: [ "Small matched context." ],
      answer_status: "answered",
      blocked_category: nil,
      reason: nil
    )

    original_call = ReviewAnalysis::QuestionAnswerer.method(:call)
    ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**_kwargs| result }

    begin
      ConversationResponseJob.perform_now(conversation.id, "What billing problems appear?")
    ensure
      ReviewAnalysis::QuestionAnswerer.define_singleton_method(:call) { |**kwargs| original_call.call(**kwargs) }
    end

    messages = conversation.chat_messages.order(:created_at)
    assert_equal [ "user", "assistant" ], messages.pluck(:role)
    assert_equal "What billing problems appear?", messages.first.content
    assert_equal "Billing support is the main issue.", messages.second.content
    assert_equal "high", messages.second.content_raw.fetch("confidence")
    assert_equal [ reviews(:ready_billing).id.to_s ], messages.second.content_raw.fetch("supporting_review_ids")
    assert_equal "answered", messages.second.content_raw.fetch("answer_status")
  end

  test "blocked product questions refuse through chat persistence path" do
    conversation = Conversation.create!(product: products(:ready))

    ConversationResponseJob.perform_now(conversation.id, "What is the current weather?")

    assistant = conversation.chat_messages.order(:created_at).last
    assert_equal "assistant", assistant.role
    assert_equal "refused", assistant.content_raw.fetch("answer_status")
    assert_equal "outside_knowledge", assistant.content_raw.fetch("blocked_category")
    assert_includes assistant.content, "Trustpilot"
  end

  test "non product conversations keep generic RubyLLM chat behavior" do
    conversation = Conversation.new
    conversation.define_singleton_method(:ask) do |content, &block|
      @asked_content = content
      block.call(Struct.new(:content).new("chunk")) if block
    end
    conversation.define_singleton_method(:asked_content) { @asked_content }

    original_find = Conversation.method(:find)
    Conversation.define_singleton_method(:find) { |_id| conversation }

    begin
      ConversationResponseJob.perform_now(123, "Generic question")
    ensure
      Conversation.define_singleton_method(:find) { |*args| original_find.call(*args) }
    end

    assert_equal "Generic question", conversation.asked_content
  end
end
