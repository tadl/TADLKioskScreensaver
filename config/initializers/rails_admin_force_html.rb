# config/initializers/rails_admin_force_html.rb

Rails.application.config.to_prepare do
  if defined?(RailsAdmin::MainController)
    RailsAdmin::MainController.class_eval do
      before_action :force_html_for_rails_admin

      private

      def force_html_for_rails_admin
        # Treat any Turbo-Stream request as plain HTML so RailsAdmin never returns 406
        request.format = :html if request.format == Mime[:turbo_stream]
      end
    end
  end
end
