# config/initializers/rails_admin.rb

Rails.application.config.to_prepare do
  #
  # 1) Disable Turbo on all RailsAdmin forms
  #
  if defined?(RailsAdmin::MainHelper)
    RailsAdmin::MainHelper.module_eval do
      prepend(Module.new do
        # Force every rails_admin_form_for to render with data-turbo="false"
        def rails_admin_form_for(record, *args, &block)
          options = args.first.is_a?(Hash) ? args.shift.dup : {}
          options[:html] ||= {}
          options[:html]['data-turbo'] = false
          super(record, options, *args, &block)
        end
      end)
    end
  end

  #
  # 2) Only preview persisted ActiveStorage blobs
  #
  if defined?(RailsAdmin::Config::Fields::Types::ActiveStorage)
    RailsAdmin::Config::Fields::Types::ActiveStorage.class_eval do
      register_instance_option :resource_url do
        attached = bindings[:object].public_send(name)
        blob     = attached&.blob
        if blob&.persisted?
          Rails.application.routes.url_helpers.rails_blob_path(
            blob,
            host: bindings[:view].request.base_url
          )
        end
      end

      register_instance_option :pretty_value do
        blob = bindings[:object].public_send(name)&.blob
        if blob&.persisted?
          view = bindings[:view]
          url  = view.rails_blob_path(blob, host: view.request.base_url)
          view.tag.img(src: url, style: 'max-width: 200px;')
        end
      end
    end
  end

  #
  # 3) Safe generic FileUpload preview
  #
  if defined?(RailsAdmin::Config::Fields::Types::FileUpload)
    RailsAdmin::Config::Fields::Types::FileUpload.class_eval do
      register_instance_option :pretty_value do
        if (url = resource_url).present?
          bindings[:view].tag.img(src: url, style: 'max-width: 200px;')
        end
      end
    end
  end
end

#
# 4) Your normal RailsAdmin config
#
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
  config.navigation_static_links = { 'Sign out' => '/sign_out' }

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
      %i[name slug kiosks].each do |f|
        field f do
          read_only { !bindings[:controller].current_ability.can?(:manage, KioskGroup) }
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
    navigation_label    'Content'
    weight              2
    label_plural        'Slides'
    object_label_method :rails_admin_label

    list do
      field :image do
        label    'Preview'
        sortable false
        pretty_value do
          slide = bindings[:object]
          if slide.image.attached?
            thumb = slide.image.variant(resize_to_limit: [100, 100]).processed
            url   = Rails.application.routes
                         .rails_representation_url(thumb, host: bindings[:view].request.base_url)
            bindings[:view].tag.img(src: url, width: 100, height: 100)
          else
            '-'
          end
        end
      end

      %i[title display_seconds start_date end_date].each { |f| field f }
      field :kiosks do
        label    'Assigned Kiosks'
        sortable false
      end
    end

    edit do
      field :title do
        required false
        help "If you leave this blank I'll auto-fill it from the filename."
      end
      field :display_seconds do
        required false
        help "If you leave this blank I'll default it to 10 seconds."
      end
      field :start_date
      field :end_date

      field :image, :active_storage do
        label 'Slide image'
      end

      field :kiosks do
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
      end
    end
  end
end
