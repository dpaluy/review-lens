class ChatMessagesController < ApplicationController
  before_action :set_conversation

  def create
    content = params.dig(:chat_message, :content)
    if content.present?
      ConversationResponseJob.perform_later(@conversation.id, content)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @conversation }
      end
    end
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:conversation_id])
  end
end
