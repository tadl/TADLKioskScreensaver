# config/initializers/rails_admin_turbo_fallback.rb

# We need to load the MainController class so we can reopen it.
# Depending on load order, RailsAdmin::MainController may not yet be defined,
# so wrap in to_prepare to guarantee it’s there.
Rails.application.config.to_prepare do
  begin
    require 'rails_admin/main_controller'
  rescue LoadError
    # will retry on next to_prepare if not yet autoloaded
  end

  if defined?(RailsAdmin::MainController)
    RailsAdmin::MainController.class_eval do
      rescue_from ActionController::UnknownFormat do
        # If RailsAdmin doesn’t know about :turbo_stream, treat it as HTML.
        request.format = :html
        retry
      end
    end
  end
end
