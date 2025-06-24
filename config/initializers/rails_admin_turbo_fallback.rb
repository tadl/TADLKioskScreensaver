# config/initializers/rails_admin_turbo_fallback.rb

Rails.application.config.to_prepare do
  # Ensure the MainController class is loaded before we reopen it
  begin
    require 'rails_admin/main_controller'
  rescue LoadError
    # if it isn’t yet, to_prepare will fire again on next reload
  end

  if defined?(RailsAdmin::MainController)
    RailsAdmin::MainController.class_eval do
      before_action :force_html_for_turbo_stream

      private

      def force_html_for_turbo_stream
        # Turbo submits as :turbo_stream, which RailsAdmin doesn’t handle → force to HTML
        request.format = :html if request.format.symbol == :turbo_stream
      end
    end
  end
end
