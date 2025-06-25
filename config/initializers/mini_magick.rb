# config/initializers/mini_magick.rb
require "mini_magick"

MiniMagick.configure do |config|
  # use the ImageMagick CLI
  config.cli = :imagemagick

  # if you’re on dokku with the apt buildpack, ImageMagick will live under .apt
  config.cli_path = "/usr/bin"
end
