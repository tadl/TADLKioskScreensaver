Rails.application.routes.draw do
  get    '/sign_in',  to: 'sessions#new',     as: :sign_in
  match  '/sign_out', to: 'sessions#destroy', as: :sign_out, via: [:get, :delete]
  get '/auth/:provider/callback', to: 'sessions#create'

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  get "up" => "rails/health#show", as: :rails_health_check
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
