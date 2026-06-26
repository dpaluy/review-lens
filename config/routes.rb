Rails.application.routes.draw do
  resources :conversations, only: %i[ index new create show destroy ] do
    resources :chat_messages, only: [ :create ]
  end

  root "products#new"
  resources :products, only: %i[ new create show ]

  get "up" => "rails/health#show", as: :rails_health_check
end
