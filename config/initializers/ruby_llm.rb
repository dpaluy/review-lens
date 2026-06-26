RubyLLM.configure do |config|
  config.use_new_acts_as = true
  config.openai_api_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:open_ai, :api_key)
  config.default_model = ENV.fetch("OPENAI_MODEL", "gpt-5.4-mini")

  # Custom model registry class name.
  config.model_registry_class = "AIModel"
end
