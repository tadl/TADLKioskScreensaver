# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    user = User.from_omniauth(request.env['omniauth.auth'])
    if user
      sign_in_and_redirect user, event: :authentication
    else
      redirect_to new_user_session_path,
                  alert: 'Only tadl.org accounts may sign in.'
    end
  end

  def failure
    redirect_to root_path, alert: 'Authentication failed.'
  end
end

