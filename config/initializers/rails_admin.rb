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

    # “Show in app” still opens the raw image
    show_in_app do
      only ['Slide']
      link_icon 'fa fa-image'
      controller do
        proc do
          slide = @abstract_model.model.find(params[:id])
          if slide.image.attached?
            redirect_to Rails.application.routes.url_helpers.rails_blob_url(
              slide.image,
              host: request.base_url,
              disposition: "inline"
            ), allow_other_host: true
          else
            flash[:error] = "No image attached"
            redirect_to back_or_index
          end
        end
      end
    end
  end

  ### KioskGroup ###
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

  ### Kiosk ###
  config.model 'Kiosk' do
    navigation_label 'Content'
    weight          1
    label_plural    'Kiosks'

    # Show slug when kiosks are displayed elsewhere
    object_label_method :slug

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

  ### Slide ###
  config.model 'Slide' do
    navigation_label 'Content'
    weight          2
    label_plural    'Slides'
    object_label_method :rails_admin_label

    list do
      # Restore the plain image preview (no edit link)
      field :image do
        label      'Preview'
        sortable   false
        formatted_value do
          if (img = bindings[:object].image).attached?
            variant = img.variant(resize_to_limit: [100, 100]).processed
            url     = Rails.application.routes.url_helpers.rails_representation_url(
                        variant,
                        host: bindings[:view].request.base_url
                      )
            bindings[:view].tag.img(src: url, width: 100, height: 100)
          else
            '-'
          end
        end
      end

      field :title
      field :display_seconds
      field :start_date
      field :end_date

      # Default HABTM display on kiosks
      field :kiosks do
        label    'Assigned Kiosks'
        sortable false
      end
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

