# frozen_string_literal: true

class Api::KiosksController < ActionController::API
  # If you want Rails logs tagged, etc., you can inherit from ApplicationController,
  # but then you must handle CSRF. ActionController::API keeps it simple.

  before_action :authenticate_psk!

  # POST /api/kiosks/heartbeat
  def heartbeat
    payload = safe_json_payload

    kiosk_id = (payload["kiosk_id"] || request.headers["X-Kiosk-Id"]).to_s.strip
    return render json: { ok: false, error: "missing kiosk_id" }, status: :bad_request if kiosk_id.blank?

    # Optional: enforce header matches body if both provided
    header_id = request.headers["X-Kiosk-Id"].to_s.strip
    if header_id.present? && header_id != kiosk_id
      return render json: { ok: false, error: "X-Kiosk-Id does not match kiosk_id" }, status: :bad_request
    end

    ts = parse_time(payload["ts"]) || Time.zone.now

    hb = KioskHeartbeat.find_or_initialize_by(kiosk_id: kiosk_id)
    hb.last_seen_at   = ts
    hb.uptime_seconds = payload["uptime_seconds"]
    hb.kiosk_service  = payload["kiosk_service"]

    pid_count =
      payload["chromium_pid_count"] ||
      payload["chromium_pids"]&.to_s&.split&.length ||
      payload["chromium_pids"]

    hb.chromium_pids = pid_count.to_i if pid_count.present?

    hb.chromium_devtools_ok   = payload["chromium_devtools_ok"]
    hb.chromium_devtools_http = payload["chromium_devtools_http"].to_s.presence
    hb.chromium_devtools_ms   = payload["chromium_devtools_ms"]

    hb.raw_payload = payload
    hb.save!

    render json: { ok: true }
  rescue JSON::ParserError
    render json: { ok: false, error: "invalid JSON" }, status: :bad_request
  end

  # POST /api/kiosks/logs
  def logs
    payload = safe_json_payload

    kiosk_id = (payload["kiosk_id"] || request.headers["X-Kiosk-Id"]).to_s.strip
    return render json: { ok: false, error: "missing kiosk_id" }, status: :bad_request if kiosk_id.blank?

    # Batch mode: { events: [ ... ] }
    if payload["events"].is_a?(Array)
      events = payload["events"]

      # Avoid unbounded inserts if something goes nuts
      events = events.first(500)

      rows = events.map do |ev|
        ev = ev.is_a?(Hash) ? ev : { "message" => ev.to_s }

        occurred_at =
          parse_time(ev["ts"] || ev["occurred_at"]) ||
          parse_time(payload["sent_at"]) ||
          Time.zone.now

        level = ev["level"].to_s.presence
        message =
          ev["message"].to_s.presence ||
          ev["kind"].to_s.presence ||
          "(no message)"

        {
          kiosk_id: kiosk_id,
          occurred_at: occurred_at,
          level: level,
          message: message,
          raw_payload: ev,
          created_at: Time.zone.now,
          updated_at: Time.zone.now
        }
      end

      # Rails 6+: bulk insert
      KioskLog.insert_all!(rows) if rows.any?

      return render json: { ok: true, inserted: rows.size }
    end

    # Single-event mode (your existing behavior)
    ts = parse_time(payload["ts"]) || Time.zone.now

    KioskLog.create!(
      kiosk_id:    kiosk_id,
      occurred_at: ts,
      level:       payload["level"].to_s.presence,
      message:     payload["message"].to_s.presence,
      raw_payload: payload
    )

    render json: { ok: true }
  rescue JSON::ParserError
    render json: { ok: false, error: "invalid JSON" }, status: :bad_request
  end

  private

  def authenticate_psk!
    expected = ENV["KIOSK_API_PSK"].to_s
    provided = request.headers["X-Kiosk-Key"].to_s

    # Hard fail if misconfigured
    return render(json: { ok: false, error: "server missing KIOSK_API_PSK" }, status: :service_unavailable) if expected.blank?

    unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)
      render json: { ok: false, error: "unauthorized" }, status: :unauthorized
    end
  end

  def safe_json_payload
    # Rails will parse JSON into params when Content-Type is application/json,
    # but using request.raw_post keeps it explicit and predictable.
    body = request.raw_post.to_s
    body = "{}" if body.blank?
    JSON.parse(body)
  end

  def parse_time(val)
    return nil if val.blank?
    Time.zone.parse(val.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
