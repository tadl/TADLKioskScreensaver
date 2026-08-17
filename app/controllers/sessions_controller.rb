class SessionsController < ApplicationController
  def new
  end

  def create
    auth = request.env['omniauth.auth']
    return authentication_failed if auth.blank?

    user = User.from_omniauth(auth)
    if user
      session[:user_id] = user.id
      flash.discard
      redirect_to rails_admin.dashboard_path
    else
      reset_session
      redirect_to root_path, alert: "Only #{GOOGLE_DOMAIN} accounts allowed"
    end
  end

  def failure
    authentication_failed
  end

  def destroy
    reset_session
    redirect_to root_path
  end

  private

  def authentication_failed
    reset_session
    redirect_to login_path, alert: 'Authentication failed, please try again.'
  end
end
