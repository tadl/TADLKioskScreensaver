# frozen_string_literal: true

class Api::KiosksController < ActionController::API
  MAX_BODY_BYTES = 1.megabyte
  MAX_CLOCK_SKEW = 1.day
  MAX_EVENT_AGE = 1.year

  class InvalidPayload < StandardError; end
  class PayloadTooLarge < StandardError; end

  # If you want Rails logs tagged, etc., you can inherit from ApplicationController,
  # but then you must handle CSRF. ActionController::API keeps it simple.

  before_action :authenticate_psk!

  # POST /api/kiosks/heartbeat
  def heartbeat
    payload = safe_json_payload

    kiosk_id = validated_kiosk_id(payload)

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

    online_notice_recorded = KioskHeartbeat.transaction do
      hb.save!
      record_online_notice!(kiosk_id, ts, payload["online_notice"])
    end

    render json: { ok: true, online_notice_recorded: online_notice_recorded }
  rescue JSON::ParserError, InvalidPayload => e
    render json: { ok: false, error: e.message.presence || "invalid JSON" }, status: :bad_request
  rescue PayloadTooLarge
    render json: { ok: false, error: "payload too large" }, status: :content_too_large
  end

  # POST /api/kiosks/logs
  def logs
    payload = safe_json_payload

    kiosk_id = validated_kiosk_id(payload)

    inserted = KioskLogIngestor.new(
      payload: payload,
      kiosk_id: kiosk_id,
      request_meta: {
        "remote_ip" => request.remote_ip,
        "user_agent" => request.user_agent.to_s.first(1_000)
      }
    ).insert!

    render json: { ok: true, inserted: inserted }
  rescue JSON::ParserError, InvalidPayload => e
    render json: { ok: false, error: e.message.presence || "invalid JSON" }, status: :bad_request
  rescue PayloadTooLarge
    render json: { ok: false, error: "payload too large" }, status: :content_too_large
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
    body = request.body.read(MAX_BODY_BYTES + 1).to_s
    raise PayloadTooLarge if body.bytesize > MAX_BODY_BYTES

    body = "{}" if body.blank?
    payload = JSON.parse(body)
    raise InvalidPayload, "JSON payload must be an object" unless payload.is_a?(Hash)

    payload
  end

  def validated_kiosk_id(payload)
    body_id = payload["kiosk_id"].to_s.strip
    header_id = request.headers["X-Kiosk-Id"].to_s.strip
    kiosk_id = body_id.presence || header_id

    raise InvalidPayload, "missing kiosk_id" if kiosk_id.blank?
    if body_id.present? && header_id.present? && body_id != header_id
      raise InvalidPayload, "X-Kiosk-Id does not match kiosk_id"
    end
    unless kiosk_id.length <= 253 && Host::NAME_FORMAT.match?(kiosk_id)
      raise InvalidPayload, "invalid kiosk_id"
    end

    kiosk_id
  end

  def parse_time(val)
    return nil if val.blank?

    parsed = Time.zone.parse(val.to_s)
    return nil if parsed < MAX_EVENT_AGE.ago || parsed > MAX_CLOCK_SKEW.from_now

    parsed
  rescue ArgumentError, TypeError
    nil
  end

  def record_online_notice!(kiosk_id, occurred_at, value)
    message = value.to_s.strip.first(KioskLogIngestor::MAX_MESSAGE_LENGTH)
    return false if message.blank?

    existing_notice = KioskLog
      .where(kiosk_id: kiosk_id)
      .where("raw_payload @> ?", { event: { kind: "kiosk_online" } }.to_json)
      .exists?
    return true if existing_notice

    KioskLog.create!(
      kiosk_id: kiosk_id,
      occurred_at: occurred_at,
      level: "info",
      message: message,
      raw_payload: {
        "event" => { "kind" => "kiosk_online", "message" => message },
        "request" => { "remote_ip" => request.remote_ip }
      }
    )

    true
  end
end
