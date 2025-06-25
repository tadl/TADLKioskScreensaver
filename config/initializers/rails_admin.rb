# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  config.asset_source        = :importmap
  config.parent_controller   = '::ApplicationController'

  # == Authentication ==
  config.authenticate_with do
    redirect_to main_app.sign_in_path unless user_signed_in?
  end
  config.current_user_method(&:current_user)

  # == Authorization ==
  config.authorize_with :cancancan

  # == UI ==
  config.main_app_name            = ['Kiosk Screensaver', 'Admin']
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
    visible { bindings[:controller].current_ability.can?(:manage, Permission) }
  end

  # == UserPermission ==
  config.model 'UserPermission' do
    visible { bindings[:controller].current_ability.can?(:manage, UserPermission) }
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
      field :name do
        read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
      end
      field :slug do
        read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
      end
      field :kiosks do
        read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
      end
    end
  end

  # == Kiosk ==
  config.model 'Kiosk' do
    navigation_label 'Content'
    weight          1
    label_plural    'Kiosks'
    object_label_method :slug

    list do
      field :name
      field :slug
      field :catalog_url
      field :kiosk_group
    end

    edit do
      field :slides do
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
      end
      field :name do
        read_only { !bindings[:controller].current_ability.can?(:manage, Kiosk) }
      end
      field :slug do
        read_only { !bindings[:controller].current_ability.can?(:manage, Kiosk) }
      end
      field :catalog_url do
        read_only { !bindings[:controller].current_ability.can?(:manage, Kiosk) }
      end
      field :kiosk_group do
        read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
      end
    end
  end

  # == Slide ==
  config.model 'Slide' do
    navigation_label 'Content'
    weight          2
    label_plural    'Slides'
    object_label_method :rails_admin_label

    list do
      field :image do
        label    'Preview'
        sortable false
        formatted_value do
          slide = bindings[:object]
          if slide.image.attached?
            thumb = slide.image.variant(resize_to_limit: [100, 100]).processed
            url   = Rails.application.routes.url_helpers.
                      rails_representation_url(thumb, host: bindings[:view].request.base_url)
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

      field :kiosks do
        label    'Assigned Kiosks'
        sortable false
      end
    end

    edit do
      field :title

      field :image, :active_storage do
        # only persisteds get a signed_id
        cache_value do
          rec = bindings[:object]
          rec.persisted? && rec.image.attached? ? rec.image.signed_id : nil
        rescue
          nil
        end

        resource_url do
          rec = bindings[:object]
          rec.image.attached? ? bindings[:view].url_for(rec.image) : nil
        rescue
          nil
        end
      end

      field :display_seconds
      field :start_date
      field :end_date

      field :kiosks do
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
      end
    end
  end
end
