# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  # Use importmap for your app assets, then sprockets for RailsAdmin’s
  config.asset_source    = :importmap
  config.main_app_name   = [ "Kiosk Screensaver", "Admin" ]
  config.included_models = ['KioskGroup', 'Kiosk', 'Slide']
  config.asset_source    = :sprockets

  ### Actions ###
  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete

    # Show in app → open the raw image for Slides
    show_in_app do
      only ['Slide']
      link_icon 'fa fa-image'
      controller do
        proc do
          slide = @abstract_model.model.find(params[:id])
          if slide.image.attached?
            url = Rails.application.routes.url_helpers.rails_blob_url(
              slide.image,
              host: request.base_url,
              disposition: "inline"
            )
            redirect_to url, allow_other_host: true
          else
            flash[:error] = "No image attached"
            redirect_to back_or_index
          end
        end
      end
    end
  end

  ### Models ###

  # 1) KioskGroup admin UI
  config.model 'KioskGroup' do
    navigation_label 'Content'
    weight          0
    label_plural    'Kiosk Groups'

    list do
      field :name
      field :slug
      field :kiosks
    end

    edit do
      field :name
      field :slug
      field :kiosks
    end
  end

  # 2) Kiosk admin UI
  config.model 'Kiosk' do
    navigation_label 'Content'
    weight          1
    label_plural    'Kiosks'

    list do
      field :name
      field :slug
      field :catalog_url
      field :kiosk_group
    end

    edit do
      field :name
      field :slug
      field :catalog_url
      field :kiosk_group
      field :slides
    end
  end

  # 3) Slide admin UI
  config.model 'Slide' do
    navigation_label 'Content'
    weight          2
    label_plural    'Slides'

    # Use your custom label method
    object_label_method :rails_admin_label

    list do
      field :title
      field :display_seconds
      field :start_date
      field :end_date
      field :kiosks
    end

    edit do
      field :title
      field :image, :active_storage
      field :display_seconds
      field :start_date
      field :end_date
      field :kiosks
    end
  end
end

