# config/initializers/rails_admin_disable_turbo.rb

# Make sure RailsAdmin’s form_for helper never uses remote/Turbo submissions.
require "rails_admin/main_helper"

RailsAdmin::MainHelper.module_eval do
  def rails_admin_form_for(record_or_name, options = {}, &block)
    # RailsAdmin by default forces remote: true; override it:
    options[:remote] = false

    # Also disable Turbo Drive for this form
    options[:html]             ||= {}
    options[:html]["data-turbo"] = "false"

    super
  end
end
