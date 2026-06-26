class ChatMessagesController < ApplicationController
  def create
    if params[:conversation_id].present?
      create_conversation_message
    else
      create_product_conversation
    end
  end

  private

  def create_conversation_message
    @conversation = Conversation.find(params[:conversation_id])
    content = params.dig(:chat_message, :content)

    if content.present?
      ConversationResponseJob.perform_later(@conversation.id, content)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @conversation }
      end
    end
  end

  def create_product_conversation
    product = Product.find(params[:product_id])
    question = params[:question].to_s.strip

    return redirect_to product if question.blank?
    return redirect_to root_path unless product.ready? && product.reviews_count > 0

    conversation = Conversation.create!(product:)
    ConversationResponseJob.perform_later(conversation.id, question)

    redirect_to conversation
  end
end
