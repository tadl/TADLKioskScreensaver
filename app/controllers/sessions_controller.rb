class SessionsController < ApplicationController
  def new
    # send them into Google
    redirect_to '/auth/google_oauth2'
  end

  def create
    auth = request.env['omniauth.auth']
    user = User.from_omniauth(auth)
    if user
      session[:user_id] = user.id
      session[:admin]   = user.admin?
      flash.discard
      redirect_to rails_admin.dashboard_path
    else
      reset_session
      redirect_to root_path, alert: "Only #{GOOGLE_DOMAIN} accounts allowed"
    end
  end

  def failure
    # OAuth failure (e.g. wrong domain)
    reset_session
    redirect_to sign_in_path, alert: 'Authentication failed, please try again.'
  end

  def destroy
    reset_session
    redirect_to root_path
  end
end

