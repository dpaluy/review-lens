class ProductChatBroadcaster
  def self.stream_for(conversation)
    "product_conversation_#{conversation.id}"
  end

  def self.assistant_created(chat_message)
    conversation = chat_message.conversation
    stream = stream_for(conversation)

    Turbo::StreamsChannel.broadcast_remove_to stream, target: "product_chat_pending"
    Turbo::StreamsChannel.broadcast_replace_to stream,
      target: "product_chat_form",
      partial: "products/chat_form",
      locals: { product: conversation.product }
    Turbo::StreamsChannel.broadcast_append_to stream,
      target: "chat_messages",
      partial: "chat_messages/assistant",
      locals: { chat_message: }
  end
end
