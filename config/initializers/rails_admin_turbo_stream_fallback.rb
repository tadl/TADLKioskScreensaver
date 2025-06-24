# frozen_string_literal: true
# config/initializers/rails_admin_turbo_stream_fallback.rb

# Monkey-patch RailsAdmin::MainController so that if RailsAdmin
# ever raises UnknownFormat (e.g. a Turbo Stream request),
# we force the request back to HTML and retry.
Rails.application.config.to_prepare do
  # Make sure the class is loaded before we patch
  require 'rails_admin/main_controller'

  RailsAdmin::MainController.class_eval do
    rescue_from ActionController::UnknownFormat do
      request.format = :html
      retry
    end
  end
end
