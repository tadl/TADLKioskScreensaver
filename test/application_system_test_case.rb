require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Use Capybara's port and threads without loading deployment-specific Puma settings.
  Capybara.server = :puma, { config_files: ["-"] }

  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
end
