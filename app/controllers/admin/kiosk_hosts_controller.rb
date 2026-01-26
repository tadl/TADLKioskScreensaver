# frozen_string_literal: true

class Admin::KioskHostsController < ApplicationController
  before_action :require_login!
  before_action :authorize_kiosk_host!

  # GET /admin/kiosk_hosts/:host.json
  def show
    host = params[:host].to_s.strip
    return render json: { ok: false, error: "missing host" }, status: :bad_request if host.blank?

    hb = KioskHeartbeat.find_by(kiosk_id: host)

    logs = KioskLog
      .where(kiosk_id: host)
      .order(occurred_at: :desc)
      .limit(80)
      .select(:occurred_at, :level, :message, :raw_payload)

    render json: {
      ok: true,
      host: host,
      heartbeat: serialize_heartbeat(hb),
      logs: logs.map { |l| serialize_log(l) }
    }
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

  def serialize_heartbeat(hb)
    return nil unless hb

    rp = hb.raw_payload.is_a?(Hash) ? hb.raw_payload : {}

    {
      kiosk_id: hb.kiosk_id,
      last_seen_at: hb.last_seen_at,
      uptime_seconds: hb.uptime_seconds,
      kiosk_service: hb.kiosk_service,
      chromium_pids: hb.chromium_pids,
      chromium_devtools_ok: rp["chromium_devtools_ok"],
      chromium_devtools_http: rp["chromium_devtools_http"],
      chromium_devtools_ms: rp["chromium_devtools_ms"]
    }
  end

  # Supports:
  # - New shape: raw_payload["event"] + raw_payload["envelope"]
  # - Old shape: raw_payload is the event hash itself
  def extract_event_and_envelope(raw_payload)
    rp = raw_payload.is_a?(Hash) ? raw_payload : {}

    if rp.key?("event") || rp.key?("envelope")
      event = rp["event"].is_a?(Hash) ? rp["event"] : {}
      envelope = rp["envelope"].is_a?(Hash) ? rp["envelope"] : {}
      request_meta = rp["request"].is_a?(Hash) ? rp["request"] : {}
      [event, envelope, request_meta]
    else
      # legacy: treat whole payload as event
      [rp, {}, {}]
    end
  end

  def serialize_log(log)
    event, envelope, request_meta = extract_event_and_envelope(log.raw_payload)

    {
      occurred_at: log.occurred_at,
      level: log.level,
      message: log.message,

      # High-value context for browser/extension events
      kind: event["kind"],
      tab_url: event["tab_url"],
      href: event["href"],
      source: event["source"],
      lineno: event["lineno"],
      colno: event["colno"],
      stack: event["stack"],
      tab_id: event["tab_id"],

      # Batch/envelope metadata (if present)
      sent_at: envelope["sent_at"],
      envelope_ts: envelope["ts"],

      # Optional request metadata (if you store it)
      remote_ip: request_meta["remote_ip"],
      user_agent: request_meta["user_agent"]
    }
  end
end
