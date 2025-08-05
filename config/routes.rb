Rails.application.routes.draw do
  get    '/login',  to: 'sessions#new',     as: :login
  delete  '/logout', to: 'sessions#destroy', as: :logout
  get '/auth/:provider/callback', to: 'sessions#create'

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  get "up" => "rails/health#show", as: :rails_health_check

  get '/slides.json', to: 'screensaver#slides_json', defaults: { format: :json }

  get '/exit', to: 'screensaver#exit', as: :exit_screensaver

  root to: "screensaver#index"

  %w(404 422 500).each do |code|
    match code,
      to: "errors#show",
      via: :all,
      defaults: { code: code },
      constraints: ->(req) { req.format.html? }
  end

  match "*unmatched",
    to: "errors#show",
    via: :all,
    defaults: { code: "404" },
    constraints: ->(req) { req.format.html? }

end
