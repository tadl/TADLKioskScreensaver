# config/initializers/rails_admin_force_html.rb

Rails.application.config.to_prepare do
  require 'rails_admin/application_controller'

  RailsAdmin::ApplicationController.class_eval do
    # run *before* any action—wipe out any Turbo or other formats
    prepend_before_action :force_html_request_format

    private

    def force_html_request_format
      request.formats = [:html]
    end
  end
end
