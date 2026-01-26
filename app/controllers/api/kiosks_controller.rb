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

    now = Time.zone.now

    # Treat everything as batch internally; single-event payloads become a 1-item array.
    events =
      if payload["events"].is_a?(Array)
        payload["events"]
      else
        [payload]
      end

    # Avoid unbounded inserts if something goes nuts
    events = events.first(500)

    # Envelope == everything except the events array.
    envelope = payload.is_a?(Hash) ? payload.dup : {}
    envelope.delete("events")

    request_meta = {
      "remote_ip"  => request.remote_ip,
      "user_agent" => request.user_agent
    }

    rows = events.map do |ev|
      ev = ev.is_a?(Hash) ? ev : { "message" => ev.to_s }

      occurred_at =
        parse_time(ev["ts"] || ev["occurred_at"]) ||
        parse_time(envelope["ts"] || envelope["sent_at"]) ||
        now

      level = ev["level"].to_s.presence

      kind = ev["kind"].to_s.presence
      base_message =
        ev["message"].to_s.presence ||
        kind ||
        "(no message)"

      # Helpful, consistent summary line (kept reasonably short for list views)
      message =
        if kind.present? && ev["message"].to_s.presence
          "[#{kind}] #{base_message}"
        else
          base_message
        end

      message = message.to_s
      message = message[0, 4000] if message.length > 4000

      # Store *everything*:
      # - envelope (sent_at, kiosk_id, kiosk, etc.)
      # - event (all the detailed fields like lineno, colno, tab_url, stack, etc.)
      # - request metadata (ip/ua)
      raw_payload = {
        "envelope" => envelope,
        "event"    => ev,
        "request"  => request_meta
      }

      {
        kiosk_id:     kiosk_id,
        occurred_at:  occurred_at,
        level:        level,
        message:      message,
        raw_payload:  raw_payload,
        created_at:   now,
        updated_at:   now
      }
    end

    if rows.any?
      # Rails 6+ bulk insert
      KioskLog.insert_all!(rows)
    end

    render json: { ok: true, inserted: rows.size }
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
