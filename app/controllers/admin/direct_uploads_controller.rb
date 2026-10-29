# frozen_string_literal: true

# Keep Active Storage's upload protocol and CSRF protection, with the same
# permission required to upload a slide through the admin interface.
class Admin::DirectUploadsController < ActiveStorage::DirectUploadsController
  before_action :authorize_slide_upload
  before_action { response.headers["Cache-Control"] = "no-store" }

  private

  def authorize_slide_upload
    user = User.find_by(id: session[:user_id])
    return head :unauthorized unless user

    head :forbidden unless Ability.new(user).can?(:create, Slide)
  end
end
