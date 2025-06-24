# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  config.asset_source       = :importmap
  config.parent_controller  = '::ApplicationController'

  # == Authentication ==
  config.authenticate_with do
    redirect_to main_app.sign_in_path unless user_signed_in?
  end
  config.current_user_method(&:current_user)

  # == Authorization ==
  config.authorize_with :cancancan

  # == UI ==
  config.main_app_name   = ['Kiosk Screensaver', 'Admin']
  config.included_models = %w[KioskGroup Kiosk Slide Permission UserPermission]

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
      field :name do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, KioskGroup)
        end
      end
      field :slug do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, KioskGroup)
        end
      end
      field :kiosks do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, KioskGroup)
        end
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
        read_only do
          !bindings[:controller].current_ability.can?(:manage, Slide)
        end
      end
      field :name do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, Kiosk)
        end
      end
      field :slug do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, Kiosk)
        end
      end
      field :catalog_url do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, Kiosk)
        end
      end
      field :kiosk_group do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, KioskGroup)
        end
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
      # just show the attachment-link
      field :image, :active_storage
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

      # use the built-in ActiveStorage uploader, but turn off cache on new records
      field :image, :active_storage do
        cache_method false
      end

      field :display_seconds
      field :start_date
      field :end_date
      field :kiosks do
        read_only do
          !bindings[:controller].current_ability.can?(:manage, Slide)
        end
      end
    end
  end
end
