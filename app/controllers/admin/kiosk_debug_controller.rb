# frozen_string_literal: true

class Admin::KioskDebugController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_kiosk_access!

  # GET /admin/kiosk_debug/:host
  def show
    host = params[:host].to_s.strip
    raise ActiveRecord::RecordNotFound if host.blank?

    # You may have different models; adjust names as needed.
    hb = KioskHeartbeat.find_by(kiosk_id: host) # your kiosks use inventory_hostname_short
    logs = KioskLog.where(kiosk_id: host).order(occurred_at: :desc).limit(50)

    render partial: "admin/kiosk_debug_modal_body",
           locals: { host: host, heartbeat: hb, logs: logs },
           layout: false
  end

  private

  def authorize_kiosk_access!
    return if current_user&.admin?

    # If you have a mapping of hosts->kiosk->group, enforce here.
    # Minimal safe default: non-admins forbidden until you wire proper scoping.
    head :forbidden
  end
end
