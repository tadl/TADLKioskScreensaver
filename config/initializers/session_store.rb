# config/initializers/session_store.rb

Rails.application.config.session_store :cookie_store,
  key: '_kiosk_screensaver_session',
  same_site: :lax
