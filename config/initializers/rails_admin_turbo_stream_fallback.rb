# config/initializers/rails_admin_turbo_stream_fallback.rb

# Monkey-patch RailsAdmin’s controller to coerce turbo_stream into HTML
RailsAdmin::ApplicationController.class_eval do
  before_action :force_html_for_turbo_stream

  private

  def force_html_for_turbo_stream
    if request.format.symbol == :turbo_stream
      request.format = :html
    end
  end
end
