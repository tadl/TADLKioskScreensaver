# config/environments/production.rb

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Force all access over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # (let your webserver handle static assets)
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress CSS using a preprocessor.
  config.assets.css_compressor = nil

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Set log level from ENV (default to :info)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym

  # -------------------------------------------------------------------
  # ** dual logger setup: write to both log/production.log and to STDOUT **
  # -------------------------------------------------------------------

  # 1) build the file logger
  file_logger = ActiveSupport::Logger.new(Rails.root.join("log", "production.log"))
  file_logger.level     = Logger.const_get(config.log_level.to_s.upcase)
  file_logger.formatter = config.log_formatter

  # 2) build the STDOUT logger
  stdout_logger = ActiveSupport::Logger.new($stdout)
  stdout_logger.level     = Logger.const_get(config.log_level.to_s.upcase)
  stdout_logger.formatter = config.log_formatter

  # 3) broadcast STDOUT -> file
  stdout_logger.extend(ActiveSupport::Logger.broadcast(file_logger))

  # 4) wrap in TaggedLogging
  config.logger = ActiveSupport::TaggedLogging.new(stdout_logger)

  # -------------------------------------------------------------------
  # Everything else as before...
  # -------------------------------------------------------------------

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job.
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "kiosk_screensaver_production"

  config.action_mailer.perform_caching = false

  # Enable locale fallbacks for I18n.
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = ["your.domain.com"]

  # Skip DNS rebinding protection for the health check endpoint.
  # config.host_authorization = { exclude: ->(req) { req.path == "/up" } }
end

