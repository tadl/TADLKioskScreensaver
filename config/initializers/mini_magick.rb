# config/initializers/mini_magick.rb
require "mini_magick"

MiniMagick.configure do |config|
  # make sure we use ImageMagick’s `convert`/`identify`
  config.cli     = :imagemagick
  # point at the system‐installed binary
  config.cli_path = "/usr/bin"
  # don’t blow up if you validate on create; you’ll still see errors at processing time
  config.validate_on_create = true
end
