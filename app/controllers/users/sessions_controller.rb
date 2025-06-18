# app/controllers/users/sessions_controller.rb
class Users::SessionsController < Devise::SessionsController
  def new
    redirect_to '/auth/google_oauth2'
  end
end

