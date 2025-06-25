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
  config.navigation_static_links  = { 'Sign out' => '/sign_out' }

  # == Actions ==
  config.actions do
    dashboard
    index

    new do
      except ['UserPermission']
    end

    export
    bulk_delete
    show
    edit

    delete do
      except ['UserPermission', 'Kiosk', 'KioskGroup']
    end
  end

  # == Permission ==
  config.model 'Permission' do
    navigation_label 'Admin'
    visible do
      bindings[:controller].current_ability.can?(:manage, Permission)
    end
  end

  # == UserPermission (aka Users) ==
  config.model 'UserPermission' do
    navigation_label 'Admin'
    label               'User'
    label_plural        'Users'
    object_label_method :rails_admin_label

    visible do
      bindings[:controller].current_ability.can?(:manage, UserPermission)
    end

    list do
      field :user
      field :permission
      field :kiosk_groups do
        pretty_value do
          bindings[:object].kiosk_groups.map(&:name).join(', ')
        end
      end
    end

    create do
      field :user do
        help 'Pick the Google-OAuth user to grant a role to.'
      end
      field :permission
      field :kiosk_groups do
        help 'Select which kiosk groups this user may manage.'
      end
    end

    edit do
      field :user do
        read_only true
        help 'Users are managed via Google OAuth; you cannot change this here.'
      end
      field :permission
      field :kiosk_groups do
        help 'Select which kiosk groups this user may manage.'
      end
    end
  end

  # == KioskGroup ==
  config.model 'KioskGroup' do
    navigation_label 'Content'
    weight           0
    label_plural     'Kiosk Groups'

    visible do
      bindings[:controller].current_user.admin?
    end

    list do
      field :name
      field :slug
      field :kiosks
    end

    edit do
      %i[name slug kiosks].each do |f|
        field f do
          read_only true
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
      # Only slides picker for non-admins
      field :slides do
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
        help 'Only slides at exactly 1920×1080 are available here.'
        associated_collection_scope do
          Proc.new do |scope|
            scope
              .joins(image_attachment: :blob)
              .where("(active_storage_blobs.metadata::json->>'width')  = '1920'")
              .where("(active_storage_blobs.metadata::json->>'height') = '1080'")
          end
        end
      end

      # Hide all other fields
      %i[name slug catalog_url kiosk_group].each do |f|
        field f do
          visible false
        end
      end
    end
  end

  # == Slide ==
  config.model 'Slide' do
    navigation_label 'Content'
    weight           2
    label_plural     'Slides'
    object_label_method :rails_admin_label

    list do
      row_css_class do
        md = bindings[:object].image_metadata
        'error' if md['width'] != 1920 || md['height'] != 1080
      end

      field :image do
        label    'Preview'
        sortable false
        formatted_value do
          slide = bindings[:object]
          if slide.image.attached?
            thumb = slide.image.variant(resize_to_limit: [100, 100]).processed
            url   = Rails.application.routes.url_helpers.rails_representation_url(
                     thumb,
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

      field :image_metadata do
        label 'Dimensions'
        pretty_value do
          md = bindings[:object].image_metadata
          w, h = md['width'], md['height']
          "#{w || '?'}×#{h || '?'} " +
            (w == 1920 && h == 1080 ?
              '<span class="text-success">✓</span>' :
              '<span class="text-danger font-weight-bold">✕</span>')
        end
      end

      field :kiosks do
        label    'Assigned Kiosks'
        sortable false
      end

    end

    create do
      field :title do
        required false
        help 'Leave blank to auto-fill from filename.'
      end
      field :image, :active_storage do
        help 'Upload a 1920×1080px image.'
      end
      field :display_seconds do
        required false
        help 'Leave blank to default to 10 seconds.'
      end
      field :start_date
      field :end_date
    end

    update do
      field :title do
        required false
        help 'Leave blank to auto-fill from filename.'
      end
      field :image, :active_storage do
        help 'Upload a 1920×1080px image.'
      end
      field :display_seconds do
        required false
        help 'Leave blank to default to 10 seconds.'
      end
      field :start_date
      field :end_date

      field :kiosks do
        # only show kiosk-assignment if slide is 1920×1080
        visible do
          md = bindings[:object].image_metadata
          md['width'] == 1920 && md['height'] == 1080
        end
        read_only { !bindings[:controller].current_ability.can?(:manage, Slide) }
        help 'You can only assign a kiosk to a 1920×1080 slide.'

        associated_collection_scope do
          # use closure to capture bindings
          current_user = bindings[:controller].current_user
          Proc.new do |scope|
            if current_user.admin?
              scope
            else
              scope.where(kiosk_group_id: current_user.kiosk_group_ids)
            end
          end
        end
      end
    end

  end
end

