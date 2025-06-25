# config/initializers/rails_admin_disable_turbo.rb
Rails.application.config.to_prepare do
  # Reopen RailsAdmin’s form helper to force plain HTML POSTS
  RailsAdmin::MainHelper.module_eval do
    def rails_admin_form_for(record_or_name, options = {}, &block)
      # Never use remote/Turbo for any RailsAdmin forms
      options[:remote] = false
      options[:html]   ||= {}
      options[:html]["data-turbo"] = "false"
      super
    end
  end
end
