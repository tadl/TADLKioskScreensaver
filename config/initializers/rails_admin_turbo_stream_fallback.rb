# frozen_string_literal: true
# config/initializers/rails_admin_turbo_stream_fallback.rb

# If RailsAdmin ever gets a turbo_stream request it can’t handle,
# convert it to HTML so the normal RailsAdmin views will render.
Rails.application.config.to_prepare do
  # make sure the controller is loaded
  require 'rails_admin/main_controller'

  RailsAdmin::MainController.class_eval do
    # run before every action
    prepend_before_action do
      # in Rails 7 Turbo, request.format.symbol == :turbo_stream
      if request.format.symbol == :turbo_stream
        request.format = :html
      end
    end
  end
end
