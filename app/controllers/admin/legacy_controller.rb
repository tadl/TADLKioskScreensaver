# frozen_string_literal: true

class Admin::LegacyController < Admin::BaseController
  PATHS = { "slide" => "slides", "kiosk" => "kiosks", "kiosk_group" => "kiosk_groups",
    "host" => "hosts", "permission" => "permissions", "user_permission" => "user_permissions" }.freeze

  def show
    target = "/admin/#{PATHS.fetch(params[:model_name])}"
    case params[:legacy_action]
    when "new"
      target += "/new" unless params[:model_name] == "user_permission"
    when "show", "edit"
      return head :not_found unless params[:id].to_s.match?(/\A\d+\z/)
      target += "/#{params[:id]}"
      target += "/edit" if params[:legacy_action] == "edit"
    end
    redirect_to target, status: :see_other
  end
end
