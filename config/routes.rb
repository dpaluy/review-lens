Rails.application.routes.draw do
  unless Rails.env.production?
    resources :conversations, path: "internal/conversations", only: %i[index new create show destroy] do
      resources :chat_messages, only: [ :create ]
    end
  end

  root "products#new"
  resources :products, only: %i[new create show] do
    resources :chat_messages, only: [ :create ] do
      delete :clear, on: :collection
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
