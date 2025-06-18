# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  # Asset loading
  config.asset_source    = :importmap
  config.main_app_name   = [ "Kiosk Screensaver", "Admin" ]
  config.included_models = ['KioskGroup', 'Kiosk', 'Slide']
  config.asset_source    = :sprockets

  ### Actions ###
  config.actions do
    dashboard
    index
    new
    export
    bulk_delete
    show
    edit
    delete

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

  # KioskGroup
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

  # Kiosk
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

  # Slide (with working preview column)
  config.model 'Slide' do
    navigation_label 'Content'
    weight          2
    label_plural    'Slides'

    object_label_method :rails_admin_label

    list do
      field :image do
        label 'Preview'
        sortable false

        # We use formatted_value to return HTML-safe <img> tag
        formatted_value do
          if bindings[:object].image.attached?
            # Generate a 100×100 variant and get a public service URL
            variant = bindings[:object]
                        .image
                        .variant(resize_to_limit: [100, 100])
                        .processed
            url = Rails.application.routes.url_helpers.rails_representation_url(
              variant,
              host: bindings[:view].request.base_url
            )
            # Render an <img> tag
            bindings[:view].tag.img(src: url, width: 100, height: 100)
          else
            "-"
          end
        end
      end

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

