# config/environments/production.rb

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot.
  config.eager_load = true

  # Full error reports disabled, caching turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Store uploaded files on the local file system (see config/storage.yml).
  config.active_storage.service = :local

  # Force all access over SSL.
  config.force_ssl = true

  # Let NGINX/Apache serve static files; only enable if RAILS_SERVE_STATIC_FILES is set.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Do not fallback to asset pipeline if a precompiled asset is missed.
  config.assets.compile = false
  config.assets.css_compressor = nil

  # Prepend log lines with request IDs.
  config.log_tags = [:request_id]

  # Set level from ENV or default to :info
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info").to_sym

  # --------------------------------------------------
  # Custom MultiIO logger: STDOUT + log/production.log
  # --------------------------------------------------

  # Open the file for append and sync writes immediately
  file = File.open(Rails.root.join("log", "production.log"), "a")
  file.sync = true

  # Tiny class that fans out writes to both STDOUT and the file
  class MultiIO
    def initialize(*targets)
      @targets = targets
    end

    def write(*args)
      @targets.each { |t| t.write(*args) }
    end

    def close
      @targets.each(&:close)
    end

    def flush
      @targets.each(&:flush)
    end
  end

  # Build a logger that writes to both
  combined_io = MultiIO.new($stdout, file)
  logger     = ActiveSupport::Logger.new(combined_io)
  # Match your log level and formatting
  logger.level     = Logger.const_get(config.log_level.to_s.upcase)
  logger.formatter = config.log_formatter
  # Wrap in TaggedLogging
  config.logger    = ActiveSupport::TaggedLogging.new(logger)

  # --------------------------------------------------
  # Everything else unchanged from your prior file
  # --------------------------------------------------

  # config.cache_store = :mem_cache_store
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "kiosk_screensaver_production"

  config.action_mailer.perform_caching = false
  config.i18n.fallbacks                = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  # Host authorization / DNS rebinding protection, etc.
  # config.hosts = ["your.domain.com"]
  # config.host_authorization = { exclude: ->(req) { req.path == "/up" } }
end

