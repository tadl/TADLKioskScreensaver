# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_admin_login
  before_action { response.headers["Cache-Control"] = "no-store" }

  private

  def require_admin_login
    redirect_to login_path unless current_user
  end
end
