Rails.application.config.active_storage.variant_processor = :mini_magick

# The engine routes precede application routes. Override only upload creation;
# public blob and representation URLs must keep working for existing kiosks.
Rails.application.routes.prepend do
  post "#{ActiveStorage.routes_prefix}/direct_uploads", to: "admin/direct_uploads#create"
end
