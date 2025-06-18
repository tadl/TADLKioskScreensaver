RailsAdmin.config do |config|
  config.asset_source = :importmap

  config.main_app_name = [ "Kiosk Screensaver", "Admin" ]
  config.included_models = ['Kiosk','Slide']
  config.asset_source = :sprockets

  ### Popular gems integration

  ## == Devise ==
  # config.authenticate_with do
  #   warden.authenticate! scope: :user
  # end
  # config.current_user_method(&:current_user)

  ## == CancanCan ==
  # config.authorize_with :cancancan

  ## == Pundit ==
  # config.authorize_with :pundit

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/railsadminteam/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  # config.show_gravatar = true

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete

    show_in_app do
      only ['Slide']             # only apply this override for Slide objects
      link_icon 'fa fa-image'    # swap to an image icon (optional)

      controller do
        proc do
          slide = @abstract_model.model.find(params[:id])
          if slide.image.attached?
            # Use rails_blob_url to get a direct link to the image
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

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end

  config.model 'Kiosk' do
    navigation_label 'Content'
    weight 1
    label_plural 'Kiosks'
  end

  config.model 'Slide' do
    navigation_label 'Content'
    weight 2
    label_plural 'Slides'

    object_label_method :rails_admin_label

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
