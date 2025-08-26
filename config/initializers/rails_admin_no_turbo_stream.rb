# Force RailsAdmin actions to handle requests as HTML even if Turbo sends
# Accept: text/vnd.turbo-stream.html
Rails.application.config.to_prepare do
  # Patch the actual controller that handles /admin requests
  RailsAdmin::MainController.class_eval do
    before_action :force_html_format_for_rails_admin

    private

    def force_html_format_for_rails_admin
      fmt = request.format
      # Rails 7 format can be a Mime::Type; compare safely
      if fmt && (fmt.to_sym == :turbo_stream || fmt.to_s.include?('turbo-stream'))
        request.format = :html
      end
    end
  end
end
