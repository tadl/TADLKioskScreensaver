# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  # Use the asset pipeline (Sprockets) for RailsAdmin’s JS/CSS so its widgets work correctly
  config.asset_source      = :sprockets
  config.parent_controller = '::ApplicationController'

  # == Authentication ==
  config.authenticate_with do
    redirect_to main_app.login_path unless user_signed_in?
  end
  config.current_user_method(&:current_user)

  # == Authorization ==
  config.authorize_with :cancancan

  # == UI ==
  config.main_app_name   = ['Kiosk Screensaver', 'Admin']
  config.included_models = %w[KioskGroup Kiosk Slide Permission UserPermission Host]

  preview_thumb = lambda do |obj, view, size|
    return '-' unless obj.respond_to?(:image_attachment)

    blob = obj.image_attachment&.blob
    return '-' unless blob&.persisted?

    thumb_source = blob.variable? ? obj.image.variant(resize_to_limit: [size, size]).processed : obj.image

    begin
      thumb_url = Rails.application.routes.url_helpers.rails_representation_url(
        thumb_source, host: view.request.base_url
      )
    rescue
      thumb_url = Rails.application.routes.url_helpers.url_for(thumb_source)
    end

    full_url = Rails.application.routes.url_helpers.rails_blob_url(blob, host: view.request.base_url)

    view.link_to(full_url, target: '_blank', rel: 'noopener', data: { turbo: false }) do
      view.image_tag(
        thumb_url,
        alt: (obj.try(:title).presence || blob.filename.to_s),
        style: 'max-width:100px; height:auto; display:block;'
      )
    end
  end

  # == Actions ==
  config.actions do
    dashboard
    index

    new do
      except ['UserPermission']
      visible do
        model = bindings[:abstract_model].model
        bindings[:controller].current_ability.can?(:create, model)
      end
    end

    export
    bulk_delete
    show
    edit

    delete do
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
    visible { bindings[:controller].current_user.admin? }
  end

  # == UserPermission ==
  config.model 'UserPermission' do
    navigation_label 'Admin'
    label            'User'
    label_plural     'Users'
    object_label_method :rails_admin_label

    visible { bindings[:controller].current_ability.can?(:manage, UserPermission) }

    list do
      field :user do
        label 'User'
        sortable 'users.email'
        pretty_value do
          user  = bindings[:object].user
          local = user.email.split('@').first
          name  = user.full_name.presence || user.email
          "#{name} (#{local})"
        end
      end
      field :permission
      field :kiosk_groups do
        pretty_value { bindings[:object].kiosk_groups.map(&:name).join(', ') }
      end
    end

    create do
      field(:user)          { help 'Pick the Google-OAuth user to grant a role to.' }
      field :permission
      field(:kiosk_groups)  { help 'Select which kiosk groups this user may manage.' }
    end

    edit do
      field(:user)          { read_only true; help 'Users are managed via Google OAuth; you cannot change this here.' }
      field :permission
      field(:kiosk_groups)  { help 'Select which kiosk groups this user may manage.' }
    end
  end

  # == Host ==
  config.model 'Host' do
    navigation_label 'Admin'
    label            'Host'
    label_plural     'Hosts'

    visible do
      bindings[:controller].current_user.admin?
    end

    list do
      field :name
      field :location
      field :active
      field :notes

      field :kiosk_statuses do
        label 'Statuses'
        pretty_value { bindings[:object].kiosk_statuses.count }
      end

      field :kiosk_sessions do
        label 'Sessions'
        pretty_value { bindings[:object].kiosk_sessions.count }
      end
    end

    show do
      field :name
      field :location
      field :active
      field :notes
      field :kiosk_statuses
      field :kiosk_sessions
      field :created_at
      field :updated_at
    end

    edit do
      field :name do
        help 'Hostname as reported by the kiosk (e.g. nucpac02). Changing this will detach it from existing status/session rows.'
      end
      field :location
      field :active
      field :notes
    end

    create do
      field :name
      field :location
      field :active
      field :notes
    end
  end

  # == KioskGroup ==
  config.model 'KioskGroup' do
    navigation_label 'Content'
    weight           0
    label_plural     'Kiosk Groups'

    visible do
      u = bindings[:controller].current_user
      u.admin? || u.can?('manage_kioskgroups')
    end

    list do
      register_instance_option :scoped_collection do
        current_user = bindings[:controller].current_user
        model = bindings[:abstract_model].model
        if current_user.admin? || current_user.can?('manage_kioskgroups')
          model.all
        else
          model.where(id: current_user.kiosk_group_ids)
        end
      end

      field :name
      field :slug
      field :kiosks
    end

    create do
      field :name
      field :slug
      field(:kiosks) { help 'Assign existing kiosks to this group.' }
    end

    edit do
      field :name
      field :slug
      field(:kiosks) { help 'Update which kiosks belong to this group.' }
    end
  end

  # == Kiosk ==
  config.model 'Kiosk' do
    navigation_label    'Content'
    weight              1
    label_plural        'Kiosks'
    object_label_method :slug

    list do
      register_instance_option :scoped_collection do
        user  = bindings[:controller].current_user
        model = bindings[:abstract_model].model
        scope = user.admin? ? model.all : model.where(kiosk_group_id: user.kiosk_group_ids)
        scope.includes(:kiosk_group)
      end

      field :name

      field :slug do
        label 'Slug'
        pretty_value do
          slug = bindings[:object].slug
          base = bindings[:view].request.base_url
          bindings[:view].link_to(
            slug,
            "#{base}/?kiosk=#{slug}",
            target: '_blank',
            rel: 'noopener'
          )
        end
      end

      field :catalog_url
      field :location
      field :kiosk_group

      field :slides_count do
        label      'Slides Count'
        sortable   :slides_count
        filterable true
      end
    end

    create do
      field :name
      field :slug
      field :catalog_url
      field :location do
        read_only { !bindings[:controller].current_ability.can?(:update, bindings[:object]) }
      end
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
      field :name do
        label 'Name'
        read_only do
          u = bindings[:controller].current_user
          !(u.admin? || u.can?('manage_kiosks'))
        end
      end

      field :slug do
        label 'Slug'
        help 'Used in kiosk URLs; change with care.'
        read_only do
          u = bindings[:controller].current_user
          !u.admin?
        end
      end

      field :catalog_url do
        label 'Catalog URL'
        read_only do
          u = bindings[:controller].current_user
          !(u.admin? || u.can?('manage_kiosks'))
        end
      end

      field :kiosk_group do
        label 'Kiosk Group'
        read_only do
          u = bindings[:controller].current_user
          !(u.admin? || u.can?('manage_kioskgroups') || u.can?('manage_kiosks'))
        end
      end

      field :slides do
        read_only { !bindings[:controller].current_ability.can?(:update, bindings[:object]) }
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

      field :location do
        read_only { !bindings[:controller].current_ability.can?(:manage, bindings[:object]) }
      end
    end

    show do
      field :name
      field :location
      field :slides do
        label 'Slides'
        pretty_value do
          view   = bindings[:view]
          slides = bindings[:object].slides
          thumbs = slides.map do |slide|
            att  = slide.image_attachment
            blob = att&.blob
            next '' unless att && blob && blob.key.present?

            src = (blob.respond_to?(:variable?) && blob.variable?) ?
              slide.image.variant(resize_to_limit: [150, 150]).processed :
              slide.image

            thumb_url = view.main_app.url_for(src)
            full_url  = view.main_app.url_for(slide.image)

            view.link_to(full_url, target: '_blank', rel: 'noopener') do
              view.tag.div(style: 'display:inline-block; margin:5px; text-align:center;') do
                view.tag.img(src: thumb_url, style: 'max-width:150px; max-height:150px;') +
                view.tag.br +
                view.tag.span(slide.title)
              end
            end
          end
          thumbs.join.html_safe
        end
      end
      field :slug
      field :catalog_url
      field :kiosk_group
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

      field :image, :string do
        label    'Preview'
        sortable false
        pretty_value { preview_thumb.call(bindings[:object], bindings[:view], 100) }
      end

      field :title
      field(:display_seconds) { label 'Display time' }
      field :start_date
      field :end_date

      field :fallback do
        label 'Fallback?'
        sortable true
        filterable true
        pretty_value { bindings[:object].fallback? ? '<span class="text-success">&#10003;</span>'.html_safe : nil }
      end

      field :image_metadata do
        label 'Valid?'
        pretty_value do
          md = bindings[:object].image_metadata
          w, h = md['width'], md['height']
          (w == 1920 && h == 1080 ?
            '<span class="text-success">✓</span>' :
            '<span class="text-danger font-weight-bold">✕</span>').html_safe
        end
      end

      field(:kiosks) { label 'Assigned Kiosks'; sortable false }
    end

    show do
      field :image, :string do
        label 'Preview'
        pretty_value { preview_thumb.call(bindings[:object], bindings[:view], 300) }
      end
      field :title
      field :link
      field :display_seconds
      field :start_date
      field :end_date
      field :fallback
      field :kiosks
      field :created_at
      field :updated_at

      configure(:image_attachment) { visible false }
      configure(:image_blob)       { visible false }
    end

    create do
      field(:title) { required false; help 'Leave blank to auto-fill from filename.' }
      field :image, :active_storage do
        label 'Image'
        help  'Upload a 1920×1080px image.'
        pretty_value { preview_thumb.call(bindings[:object], bindings[:view], 200) }
      end
      field(:display_seconds) { required false; help 'Leave blank to default to 10 seconds.' }
      field :start_date
      field :end_date
      field :fallback do
        label 'Fallback slide?'
        help  'If checked, this slide will show when no other slides are active for a kiosk.'
      end
      field :kiosks do
        label 'Assign to kiosks'
        help  'Pick the kiosks this slide should appear on.'
        associated_collection_scope do
          user = bindings[:controller].current_user
          Proc.new do |scope|
            user.admin? ? scope.order(:name) : scope.where(kiosk_group_id: user.kiosk_group_ids).order(:name)
          end
        end
      end
    end

    update do
      field(:title) { required false; help 'Leave blank to auto-fill from filename.' }
      field :image, :active_storage do
        label 'Image'
        help  'Upload a 1920×1080px image.'
        pretty_value { preview_thumb.call(bindings[:object], bindings[:view], 200) }
      end
      field(:display_seconds) { required false; help 'Leave blank to default to 10 seconds.' }
      field :start_date
      field :end_date do
        read_only do
          slide = bindings[:object]
          user  = bindings[:controller].current_user
          !user.admin? && slide.kiosks.where.not(kiosk_group_id: user.kiosk_group_ids).exists?
        end
      end
      field :fallback do
        label 'Fallback slide?'
        help  'If checked, this slide will show when no other slides are active for a kiosk.'
      end

      field(:kiosks) { help 'You can only pick among your groups—any other existing assignments will be preserved automatically.' }
    end
  end
end
