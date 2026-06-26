require "test_helper"

class RubyLlmInitializerTest < ActiveSupport::TestCase
  setup do
    @original_openai_api_key = RubyLLM.config.openai_api_key
    @original_default_model = RubyLLM.config.default_model
    @original_model_registry_class = RubyLLM.config.model_registry_class
    @original_env_openai_api_key = ENV["OPENAI_API_KEY"]
  end

  teardown do
    if @original_env_openai_api_key
      ENV["OPENAI_API_KEY"] = @original_env_openai_api_key
    else
      ENV.delete("OPENAI_API_KEY")
    end

    RubyLLM.configure do |config|
      config.openai_api_key = @original_openai_api_key
      config.default_model = @original_default_model
      config.model_registry_class = @original_model_registry_class
    end
  end

  test "configures OpenAI key from project credentials namespace" do
    ENV.delete("OPENAI_API_KEY")
    credentials = { open_ai: { api_key: "credential-openai-key" } }
    original_credentials = Rails.application.method(:credentials)

    Rails.application.define_singleton_method(:credentials) { credentials }
    begin
      load Rails.root.join("config/initializers/ruby_llm.rb")
    ensure
      Rails.application.define_singleton_method(:credentials) do |*args, **kwargs|
        original_credentials.call(*args, **kwargs)
      end
    end

    assert_equal "credential-openai-key", RubyLLM.config.openai_api_key
  end
end
