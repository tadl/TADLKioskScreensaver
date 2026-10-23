Rails.application.routes.draw do
  get    '/login',  to: 'sessions#new',     as: :login
  delete '/logout', to: 'sessions#destroy', as: :logout
  get '/auth/:provider/callback', to: 'sessions#create'
  match '/auth/failure', to: 'sessions#failure', via: [:get, :post]

  namespace :admin do
    root "dashboard#index"
    get "diagnostics/:hostname", to: "diagnostics#show", as: :diagnostic,
      constraints: { hostname: /[^\/]+/ }, format: false
    %i[slides kiosks kiosk_groups hosts permissions].each do |resource|
      resources resource, constraints: { id: /\d+/ } do
        collection do
          get :export
          post :bulk
        end
      end
    end
    resources :user_permissions, except: %i[new create], constraints: { id: /\d+/ } do
      collection do
        get :export
        post :bulk
      end
    end
    get "kiosk_hosts/:host.json",
        to: "kiosk_hosts#show",
        defaults: { format: :json },
        format: false,
        constraints: { host: /[^\/]+/ }
    get "kiosk_hosts/:host",
        to: "kiosk_hosts#show",
        defaults: { format: :json },
        format: false,
        constraints: { host: /[^\/]+/ }

    # Preserve useful read-only bookmarks from the former admin engine.
    constraints model_name: /slide|kiosk|kiosk_group|host|permission|user_permission/ do
      get ":model_name", to: "legacy#show"
      get ":model_name/new", to: "legacy#show", defaults: { legacy_action: "new" }
      get ":model_name/:id/edit", to: "legacy#show", defaults: { legacy_action: "edit" }
      get ":model_name/:id", to: "legacy#show", defaults: { legacy_action: "show" }
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  get '/slides.json', to: 'screensaver#slides_json', defaults: { format: :json }

  get '/exit', to: 'screensaver#exit', as: :exit_screensaver
  get '/home', to: 'screensaver#home', as: :home_screensaver

  namespace :api do
    namespace :kiosks do
      post :heartbeat
      post :logs
    end
  end

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
