# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  # Make these methods available in views and controllers
  helper_method :current_user, :user_signed_in?


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

