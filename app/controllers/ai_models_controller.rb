class AIModelsController < ApplicationController
  def index
    @ai_models = available_chat_models
  end

  def show
    @ai_model = AIModel.find(params[:id])
  end

  def refresh
    AIModel.refresh!
    redirect_to ai_models_path, notice: "AIModels refreshed successfully"
  end
end
