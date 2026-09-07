Rails.application.routes.draw do
  root "forecasts#show"
  resource :forecast, only: :show

  get "up" => "rails/health#show", as: :rails_health_check
end
