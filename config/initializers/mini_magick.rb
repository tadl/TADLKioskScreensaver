# config/initializers/mini_magick.rb
require "mini_magick"

# Make sure MiniMagick doesn’t try to validate too early,
# and picks up the Aptfile-installed /usr/bin/convert & identify.
MiniMagick.configure do |config|
  # skip the initial identify/format check (so you only see errors in your own validation)
  config.validate_on_create = false

  # you can also tweak how long to wait for the external calls:
  # config.timeout = 5
end

# If you really want to hard-code the path to your Aptfile binaries:
MiniMagick::Tool::Convert.path  = "/usr/bin/convert"
MiniMagick::Tool::Identify.path = "/usr/bin/identify"
