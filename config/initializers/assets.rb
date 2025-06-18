# config/initializers/assets.rb

Rails.application.config.assets.version = "1.0"

# If you have custom asset paths:
Rails.application.config.assets.paths << Rails.root.join("node_modules/@fortawesome/fontawesome-free/webfonts")

# Precompile RailsAdmin’s assets:
Rails.application.config.assets.precompile += %w(
  rails_admin.css
  rails_admin_custom.css
  rails_admin.js
)

