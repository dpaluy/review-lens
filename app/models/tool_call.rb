class ToolCall < ApplicationRecord
  acts_as_tool_call message: :chat_message
end
