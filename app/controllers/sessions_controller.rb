# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController

  def new
    redirect_to '/auth/google_oauth2'
  end

  # OmniAuth callback
  def create
    auth = request.env['omniauth.auth']
    user = User.from_omniauth(auth)
    if user
      session[:user_id] = user.id
      session[:admin]   = user.admin?
      redirect_to rails_admin.dashboard_path
    else
      reset_session
      redirect_to root_path, alert: 'Only tadl.org accounts allowed'
    end
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'Signed out'
  end
end

