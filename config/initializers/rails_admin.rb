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

  # == Actions ==
  config.actions do
    dashboard
    index
    new    { except ['UserPermission'] }
    export
    bulk_delete
    show
    edit   # back to default controller behavior
    delete do
      # Allow destroy on any model for which the user’s Ability permits :destroy
      register_instance_option :visible? do
        bindings[:controller].current_ability.can?(:destroy, bindings[:object])
      end

      register_instance_option :linkable? do
        visible?
      end
    end
  end

  # == Permission ==
  config.model 'Permission' do
    navigation_label 'Admin'
    visible do
      bindings[:controller].current_user.admin?
    end
  end

  # == UserPermission ==
  config.model 'UserPermission' do
    navigation_label 'Admin'
    label            'User'
    label_plural     'Users'
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
        help      'Users are managed via Google OAuth; you cannot change this here.'
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

    create do
      field :name
      field :slug
      field :kiosks do
        help 'Assign existing kiosks to this group.'
      end
    end

    edit do
      field :name
      field :slug
      field :kiosks do
        help 'Update which kiosks belong to this group.'
      end
    end
  end

  # == Kiosk ==
  config.model 'Kiosk' do
    navigation_label 'Content'
    weight           1
    label_plural     'Kiosks'
    object_label_method :slug

    list do
      register_instance_option :scoped_collection do
        user  = bindings[:controller].current_user
        model = bindings[:abstract_model].model
        user.admin? ? model.all : model.where(kiosk_group_id: user.kiosk_group_ids)
      end

      field :name
      field :slug
      field :catalog_url
      field :kiosk_group
      field :slides_count do
        label 'Slides Count'
        sortable :slides_count
        filterable true
      end
    end

    create do
      field :name
      field :slug
      field :catalog_url
      field :kiosk_group

      field :slides do
        help 'Only slides at exactly 1920×1080 are available here.'
        associated_collection_scope do
          Proc.new do |scope|
            scope
              .joins(image_attachment: :blob)
              .where("(active_storage_blobs.metadata::json->>'width') = '1920'")
              .where("(active_storage_blobs.metadata::json->>'height') = '1080'")
          end
        end
      end
    end

    edit do
      field :slides do
        read_only do
          !bindings[:controller].current_ability.can?(:update, bindings[:object])
        end
        help 'Only slides at exactly 1920×1080 are available here.'
        associated_collection_scope do
          Proc.new do |scope|
            scope
              .joins(image_attachment: :blob)
              .where("(active_storage_blobs.metadata::json->>'width') = '1920'")
              .where("(active_storage_blobs.metadata::json->>'height') = '1080'")
          end
        end
      end

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

          text = "#{w || '?'}×#{h || '?'} "
          if w == 1920 && h == 1080
            text << '<span class="text-success">✓</span>'
          else
            text << '<span class="text-danger font-weight-bold">✕</span>'
          end
          text.html_safe      # ← mark your markup safe so it renders
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
        help     'Leave blank to auto-fill from filename.'
      end
      field :image, :active_storage do
        help 'Upload a 1920×1080px image.'
      end
      field :display_seconds do
        required false
        help     'Leave blank to default to 10 seconds.'
      end
      field :start_date
      field :end_date
    end

    update do
      field :title do
        required false
        help     'Leave blank to auto-fill from filename.'
      end
      field :image, :active_storage do
        help 'Upload a 1920×1080px image.'
      end
      field :display_seconds do
        required false
        help     'Leave blank to default to 10 seconds.'
      end
      field :start_date
      field :end_date

      field :kiosks do
        help 'You can only pick among your groups—any other existing assignments will be preserved automatically.'
      end
    end
  end
end
