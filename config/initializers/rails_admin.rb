# config/initializers/rails_admin.rb

RailsAdmin.config do |config|
  # == Authentication ==
  config.authenticate_with do
    unless session[:user_id]
      redirect_to main_app.sign_in_path
    end
  end

  # == Authorization ==
  # Only allow admins (based on session[:user_id]) to access RailsAdmin
  config.authorize_with do |controller|
    user = User.find_by(id: controller.session[:user_id])
    unless user&.admin?
      controller.flash[:error] = 'You are not authorized to access that page.'
      controller.redirect_to controller.main_app.sign_in_path
    end
  end

  # == UI ==
  config.main_app_name   = ['Kiosk Screensaver', 'Admin']
  config.included_models = ['KioskGroup', 'Kiosk', 'Slide']

  # Put a Sign In/Out section in the sidebar
  config.navigation_static_label = 'Account'
  config.navigation_static_links = {
    'Sign in'  => '/sign_in',
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
      field :name
      field :slug
      field :kiosks
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
      field :slides
      field :name
      field :slug
      field :catalog_url
      field :kiosk_group
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
            v   = slide.image.variant(resize_to_limit: [100, 100]).processed
            url = Rails.application.routes.url_helpers.rails_representation_url(
              v,
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

