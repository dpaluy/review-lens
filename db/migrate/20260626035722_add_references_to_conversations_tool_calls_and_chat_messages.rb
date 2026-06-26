class AddReferencesToConversationsToolCallsAndChatMessages < ActiveRecord::Migration[8.1]
  def change
    add_reference :conversations, :ai_model, foreign_key: true
    add_reference :tool_calls, :chat_message, null: false, foreign_key: true
    add_reference :chat_messages, :conversation, null: false, foreign_key: true
    add_reference :chat_messages, :ai_model, foreign_key: true
    add_reference :chat_messages, :tool_call, foreign_key: true
  end
end
