class ConversationsController < ApplicationController
  before_action :set_conversation, only: %i[ show destroy ]

  def index
    @conversations = Conversation.order(created_at: :desc)
  end

  def new
    @conversation = Conversation.new
  end

  def create
    product = product_conversation_target
    return redirect_to product if product

    prompt = params.dig(:conversation, :prompt)

    if prompt.present?
      @conversation = Conversation.create!
      ConversationResponseJob.perform_later(@conversation.id, prompt)

      redirect_to @conversation, notice: "Conversation was successfully created."
    end
  end

  def show
    @chat_message = @conversation.chat_messages.build
  end

  def destroy
    @conversation.destroy!
    redirect_to conversations_path, notice: "Conversation successfully destroyed.", status: :see_other
  end

  private

  def set_conversation
    @conversation = Conversation.find(params[:id])
  end

  def product_conversation_target
    product_id = params.dig(:conversation, :product_id).presence || params[:product_id].presence
    return unless product_id

    Product.find_by(id: product_id) || root_path
  end
end
