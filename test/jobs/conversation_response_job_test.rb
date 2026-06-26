require "test_helper"

class ConversationResponseJobTest < ActiveJob::TestCase
  setup do
    RubyLLM.config.openai_api_key = "test-openai-key"
  end

  test "keeps generic RubyLLM chat behavior" do
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
