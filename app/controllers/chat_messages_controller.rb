class ChatMessagesController < ApplicationController
  def create
    if params[:conversation_id].present?
      create_conversation_message
    else
      create_product_conversation
    end
  end

  def clear
    @product = Product.find(params[:product_id])
    return redirect_to @product unless @product.reviews_queryable?

    @conversation = @product.conversation!
    @conversation.with_lock do
      @conversation.chat_messages.destroy_all
      @conversation.update!(cleared_at: Time.current)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @product }
    end
  end

  private

  def create_conversation_message
    @conversation = Conversation.find(params[:conversation_id])
    return redirect_to @conversation.product if @conversation.product_id.present?

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
    @product = Product.find(params[:product_id])
    question = params[:question].to_s.strip

    return redirect_to @product if question.blank?
    return redirect_to @product unless @product.reviews_queryable?

    @conversation = @product.conversation!
    @submitted_at = Time.current
    @user_message = @conversation.chat_messages.create!(role: "user", content: question)
    ProductConversationResponseJob.perform_later(@conversation.id, question, @submitted_at, @user_message.id)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @product }
    end
  end
end
