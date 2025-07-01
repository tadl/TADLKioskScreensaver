# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action { Current.user = current_user }
  # Make these methods available in views and controllers
  helper_method :current_user, :user_signed_in?

  rescue_from CanCan::AccessDenied do |exception|
    # For consistency with your errors controller, set these ivars
    @code    = 403
    @message = exception.message.presence || "Forbidden"

    # Render your errors/show.html.erb (no layout, since it’s standalone)
    render template: 'errors/show', status: :forbidden, layout: false
  end


  # Lookup the user from session[:user_id]
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  # True when someone is logged in
  def user_signed_in?
    current_user.present?
  end

  private

end

