# frozen_string_literal: true
# config/initializers/rails_admin_turbo_stream_fallback.rb

# If RailsAdmin ever receives a turbo_stream request it can’t handle,
# convert it to HTML so the normal RailsAdmin views will render.
Rails.application.config.to_prepare do
  # only if RailsAdmin is loaded
  if defined?(RailsAdmin::MainController)
    RailsAdmin::MainController.class_eval do
      # before every action, downgrade turbo_stream to html
      prepend_before_action do
        if request.format.symbol == :turbo_stream
          request.format = :html
        end
      end
    end
  end
end
