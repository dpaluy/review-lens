class ConversationsController < ApplicationController
  before_action :set_product, only: %i[ new create ]
  before_action :set_conversation, only: %i[ show destroy ]

  def index
    @conversations = Conversation.order(created_at: :desc)
  end

  def new
    @conversation = Conversation.new(product: @product)
  end

  def create
    prompt = params.dig(:conversation, :prompt)
    if prompt.present?
      @conversation = Conversation.create!(product: @product)
      ConversationResponseJob.perform_later(@conversation.id, prompt)

      redirect_to @conversation, notice: "Conversation was successfully created."
    end
  end

  def show
    @chat_message = @conversation.chat_messages.build
  end

  def destroy
    @conversation.destroy!
    redirect_to conversations_path, notice: "Conversation was successfully destroyed.", status: :see_other
  end

  private
    def set_product
      @product = Product.find_by(id: params.dig(:conversation, :product_id).presence || params[:product_id].presence)
    end

    def set_conversation
      @conversation = Conversation.find(params[:id])
    end
end
