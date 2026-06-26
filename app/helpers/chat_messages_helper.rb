module ChatMessagesHelper
  # Tight allowlist for rendered markdown. No `style` (keeps output safe even
  # if the parser config changes). `class`/`id` support header anchor links.
  MARKDOWN_TAGS = %w[
    p br hr h1 h2 h3 h4 h5 h6
    strong b em i del s
    ul ol li blockquote
    pre code a img
    table thead tbody tr th td
  ].freeze

  MARKDOWN_ATTRIBUTES = %w[href title src alt id class lang].freeze

  def default_model_display_name
    "Default: #{RubyLLM.config.default_model}"
  end

  # Renders trusted-ish LLM markdown to sanitized HTML.
  # Two layers: CommonMarker (unsafe: false by default strips raw HTML and
  # dangerous URLs) then Rails' safe-list sanitizer as defense in depth.
  def format_markdown(text)
    return "" if text.blank?

    html = Commonmarker.to_html(
      text.to_s,
      plugins: { syntax_highlighter: nil }
    )
    sanitize(html, tags: MARKDOWN_TAGS, attributes: MARKDOWN_ATTRIBUTES).html_safe
  end

  def tool_result_partial(message)
    name = message.respond_to?(:parent_tool_call) ? message.parent_tool_call&.name.to_s : ""
    partial_for(prefix: "chat_messages/tool_results", name: name)
  end

  def tool_call_partial(tool_call)
    partial_for(prefix: "chat_messages/tool_calls", name: tool_call.name.to_s)
  end

  private
    def partial_for(prefix:, name:)
      normalized = name.to_s.underscore.tr("-", "_")

      if normalized.present? && lookup_context.exists?(normalized, [ prefix ], true)
        "#{prefix}/#{normalized}"
      else
        "#{prefix}/default"
      end
    end
end
