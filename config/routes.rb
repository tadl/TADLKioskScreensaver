Rails.application.routes.draw do

  get    '/sign_in',  to: 'sessions#new',     as: :sign_in
  match  '/sign_out', to: 'sessions#destroy', as: :sign_out, via: [:get, :delete]
  get '/auth/:provider/callback', to: 'sessions#create'

  # ---- Custom error pages ----
  %w(403 404 422 500).each do |code|
    # handle both explicit hits ("/404") and internal exception dispatch
    match code, to: "errors#show", via: :all, defaults: { code: code }
  end

  # catch any _other_ unmatched route and treat it as a 404
  match "*unmatched", to: "errors#show", via: :all, defaults: { code: "404" }

  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  root to: "screensaver#index"

#  resources :slides, except: [:show]
#  resources :kiosks, except: [:show]
#  resources :kiosk_groups, except: [:show]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
