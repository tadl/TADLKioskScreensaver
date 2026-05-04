# frozen_string_literal: true

class Admin::KioskHostsController < ApplicationController
  before_action :require_login!
  before_action :authorize_kiosk_host!

  # GET /admin/kiosk_hosts/:host.json
  def show
    host = params[:host].to_s.strip
    return render json: { ok: false, error: "missing host" }, status: :bad_request if host.blank?

    render json: Admin::KioskHostDetails.new(host)
  end

  private

  def require_login!
    head :unauthorized unless current_user
  end

  # Non-admins can only view hosts that currently map (via KioskStatus) to kiosks in their allowed groups.
  # Admins can view anything.
  def authorize_kiosk_host!
    return if current_user&.admin?

    host = params[:host].to_s.strip
    return head :bad_request if host.blank?

    # We *do not* assume Host <-> Kiosk relationships.
    # Instead: use KioskStatus as the authoritative mapping of host -> kiosk (most recent record).
    ks = KioskStatus
      .includes(kiosk: :kiosk_group)
      .where(host: host)
      .order(updated_at: :desc, state_changed_at: :desc, id: :desc)
      .first

    return head :not_found unless ks&.kiosk

    allowed_group_ids = current_user.kiosk_group_ids.to_a
    head :forbidden unless allowed_group_ids.include?(ks.kiosk.kiosk_group_id)
  end

end
