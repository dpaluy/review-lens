RubyLLM.configure do |config|
  config.openai_api_key = ENV["OPENAI_API_KEY"].presence || Rails.application.credentials.dig(:openai_api_key)
  config.default_model = ENV["OPENAI_MODEL"] if ENV["OPENAI_MODEL"].present?

  # Custom model registry class name.
  config.model_registry_class = "AIModel"
end
