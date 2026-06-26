Rails.application.routes.draw do
  root "products#new"
  resources :products, only: %i[ new create show ]

  get "up" => "rails/health#show", as: :rails_health_check
end
