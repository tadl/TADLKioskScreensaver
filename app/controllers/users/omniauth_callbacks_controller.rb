# app/controllers/users/omniauth_callbacks_controller.rb
module Users
  class OmniauthCallbacksController < ApplicationController
    # GET|POST /auth/google_oauth2/callback
    def google_oauth2
      auth = request.env['omniauth.auth']
      user = User.from_omniauth(auth)

      if user
        # “Log in” by writing into the session
        session[:user_id] = user.id
        redirect_to main_app.admin_path, notice: "Signed in as #{user.name}"
      else
        redirect_to main_app.sign_in_path, alert: "Only #{GOOGLE_DOMAIN} accounts may sign in."
      end
    end

    # GET|POST /auth/failure
    def failure
      redirect_to main_app.root_path, alert: "Authentication failed: #{params[:message]}"
    end
  end
end

