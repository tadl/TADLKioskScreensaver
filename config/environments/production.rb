# config/environments/production.rb

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # -------------------------------------------------------------------
  # Code loading / caching
  # -------------------------------------------------------------------
  # Cache classes, eager load all, no code reloading between requests.
  config.cache_classes = true
  config.eager_load  = true
  config.enable_reloading = false

  # -------------------------------------------------------------------
  # Error reporting / caching
  # -------------------------------------------------------------------
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # -------------------------------------------------------------------
  # SSL / Static files
  # -------------------------------------------------------------------
  # Serve static if env var is set (otherwise let NGINX do it)
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Force SSL
  config.force_ssl = true
  config.assume_ssl = true

  # -------------------------------------------------------------------
  # Assets
  # -------------------------------------------------------------------
  config.assets.compile      = false
  config.assets.css_compressor = nil

  # -------------------------------------------------------------------
  # Active Storage
  # -------------------------------------------------------------------
  config.active_storage.service = :local

  # -------------------------------------------------------------------
  # Logging
  # -------------------------------------------------------------------
  # Prepend all log lines with request IDs
  config.log_tags = [:request_id]

  # Send all Rails logs to STDOUT
  logger           = ActiveSupport::Logger.new($stdout)
  logger.formatter = ::Logger::Formatter.new
  config.logger    = ActiveSupport::TaggedLogging.new(logger)

  # Set log level (default :info)
  #config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym
  config.log_level = :info

  # -------------------------------------------------------------------
  # I18n, deprecations, schema dump, etc.
  # -------------------------------------------------------------------
  config.i18n.fallbacks                  = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  # -------------------------------------------------------------------
  # (Optional) Host Authorization / health check
  # -------------------------------------------------------------------
  #config.hosts << "no"
  # config.host_authorization = { exclude: ->(req){ req.path == "/up" } }

  config.exceptions_app = self.routes
end

