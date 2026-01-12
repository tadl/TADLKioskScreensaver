# frozen_string_literal: true

class Admin::KioskHostsController < ApplicationController
  before_action :require_login!
  before_action :authorize_kiosk_host!

  # GET /admin/kiosk_hosts/:host.json
  def show
    host = params[:host].to_s

    hb = KioskHeartbeat.find_by(kiosk_id: host)

    logs = KioskLog
      .where(kiosk_id: host)
      .order(occurred_at: :desc)
      .limit(50)
      .select(:occurred_at, :level, :message)

    render json: {
      ok: true,
      host: host,
      heartbeat: hb && {
        kiosk_id: hb.kiosk_id,
        last_seen_at: hb.last_seen_at,
        uptime_seconds: hb.uptime_seconds,
        kiosk_service: hb.kiosk_service,
        chromium_pid_count: hb.chromium_pids,
        chromium_devtools_ok: hb.raw_payload["chromium_devtools_ok"],
        chromium_devtools_http: hb.raw_payload["chromium_devtools_http"],
        chromium_devtools_ms: hb.raw_payload["chromium_devtools_ms"],
        chromium_pids: hb.raw_payload["chromium_pids"]
      },
      logs: logs.map { |l|
        { occurred_at: l.occurred_at, level: l.level, message: l.message }
      }
    }
  end

  private

  def require_login!
    # You already have current_user working (seen in your logs).
    head :unauthorized unless current_user
  end

  def authorize_kiosk_host!
    return if current_user&.admin?

    host = params[:host].to_s

    # Adjust this lookup to match *your* schema.
    kiosk = Kiosk.find_by(host: host)
    return head :not_found unless kiosk

    allowed_group_ids = current_user.kiosk_group_ids.to_a
    head :forbidden unless allowed_group_ids.include?(kiosk.kiosk_group_id)
  end
end
