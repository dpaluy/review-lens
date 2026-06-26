Rails.application.routes.draw do
  resources :conversations, only: %i[ index new create show destroy ] do
    resources :chat_messages, only: [ :create ]
  end
  resources :ai_models, only: [ :index, :show ] do
    collection do
      post :refresh
    end
  end
  root "products#new"
  resources :products, only: %i[ new create show ]

  get "up" => "rails/health#show", as: :rails_health_check
end
