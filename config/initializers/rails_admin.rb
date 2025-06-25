# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  config.asset_source      = :importmap
  config.parent_controller = '::ApplicationController'

  # == Authentication ==
  config.authenticate_with do
    redirect_to main_app.sign_in_path unless user_signed_in?
  end
  config.current_user_method(&:current_user)

  # == Authorization ==
  config.authorize_with :cancancan

  # == UI ==
  config.main_app_name           = ['Kiosk Screensaver', 'Admin']
  config.included_models         = %w[KioskGroup Kiosk Slide Permission UserPermission]
  config.navigation_static_label = 'Account'
  config.navigation_static_links = {
    'Sign out' => '/sign_out'
  }

  # == Actions ==
  config.actions do
    dashboard
    index
    new
    export
    bulk_delete
    show
    edit
    delete
  end

  # == Permission ==
  config.model 'Permission' do
    visible do
      bindings[:controller].current_ability.can?(:manage, Permission)
    end
  end

  # == UserPermission ==
  config.model 'UserPermission' do
    visible do
      bindings[:controller].current_ability.can?(:manage, UserPermission)
    end
    list do
      field :user
      field :permission
    end
  end

  # == KioskGroup ==
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
      %i[name slug kiosks].each do |f|
        field f do
          read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
        end
      end
    end
  end

  # == Kiosk ==
  config.model 'Kiosk' do
    navigation_label    'Content'
    weight              1
    label_plural        'Kiosks'
    object_label_method :slug

    list do
      %i[name slug catalog_url kiosk_group].each { |f| field f }
    end

    edit do
      field :slides do
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
      end
      %i[name slug catalog_url].each do |f|
        field f do
          read_only { !bindings[:controller].current_ability.can?(:manage, Kiosk) }
        end
      end
      field :kiosk_group do
        read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
      end
    end
  end

  # == Slide ==
  config.model 'Slide' do
    navigation_label 'Content'
    weight           2
    label_plural     'Slides'
    object_label_method :rails_admin_label

    # INDEX: show preview, metadata, and highlight invalid dimensions
    list do
      # mark non-1920×1080 rows in red
      row_css_class do
        md = bindings[:object].image_metadata
        if md['width'] != 1920 || md['height'] != 1080
          'error'
        end
      end

      field :image do
        label    'Preview'
        sortable false
        formatted_value do
          slide = bindings[:object]
          if slide.image.attached?
            thumb = slide.image.variant(resize_to_limit: [100, 100]).processed
            url   = Rails.application.routes.url_helpers.rails_representation_url(
              thumb, host: bindings[:view].request.base_url
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

      field :image_metadata do
        label 'Dimensions'
        pretty_value do
          md = bindings[:object].image_metadata
          "#{md['width'] || '?'}×#{md['height'] || '?'}"
        end
      end

      field :kiosks do
        label    'Assigned Kiosks'
        sortable false
      end
    end

    # NEW FORM: no kiosks picker
    create do
      field :title do
        required false
        help "Leave blank to auto-fill from filename."
      end

      field :image, :active_storage do
        help "Upload a 1920×1080px image."
      end

      field :display_seconds do
        required false
        help "Leave blank to default to 10 seconds."
      end

      field :start_date
      field :end_date
    end

    # EDIT FORM: include kiosks picker
    update do
      field :title do
        required false
        help "Leave blank to auto-fill from filename."
      end

      field :image, :active_storage do
        help "Upload a 1920×1080px image."
      end

      field :display_seconds do
        required false
        help "Leave blank to default to 10 seconds."
      end

      field :start_date
      field :end_date

      field :kiosks do
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
      end
    end
  end
end
