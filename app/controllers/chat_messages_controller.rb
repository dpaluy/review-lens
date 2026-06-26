class ChatMessagesController < ApplicationController
  before_action :find_product

  def create
    question = params[:question].to_s.strip
    return redirect_to @product if question.blank?

    session[:chat] ||= {}
    session[:chat][@product.id.to_s] ||= []
    session[:chat][@product.id.to_s] << { "role" => "user", "text" => question, "at" => Time.current.iso8601 }

    # AI processing placeholder – wire up ReviewAnalysis::QuestionAnswerer when ready
    answer = {
      "role" => "assistant",
      "answer" => "AI analysis is being configured. Check back soon.",
      "confidence" => "low",
      "ids" => [],
      "limitations" => "AI services not yet configured."
    }
    session[:chat][@product.id.to_s] << answer

    redirect_to @product
  end

  private

  def find_product
    @product = Product.find(params[:product_id])
    redirect_to root_path unless @product.ready? && @product.reviews_count > 0
  end
end
