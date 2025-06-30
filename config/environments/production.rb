# config/environments/production.rb

require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.cache_classes                = true
  config.eager_load                   = true
  config.enable_reloading             = false

  config.consider_all_requests_local  = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled   = ENV["RAILS_SERVE_STATIC_FILES"].present?

  config.force_ssl                    = true
  config.assume_ssl                   = true

  config.assets.compile               = false
  config.assets.css_compressor        = nil

  config.active_storage.service       = :local

  config.log_tags                     = [:request_id]
  logger                              = ActiveSupport::Logger.new($stdout)
  logger.formatter                    = ::Logger::Formatter.new
  config.logger                       = ActiveSupport::TaggedLogging.new(logger)
  config.log_level                    = :info

  config.i18n.fallbacks               = true
  config.active_support.report_deprecations = false
  config.active_record.dump_schema_after_migration = false

  config.exceptions_app               = self.routes
end
