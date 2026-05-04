# frozen_string_literal: true

module Admin
  class KioskHostDetails
    LOG_LIMIT = 80

    def initialize(host)
      @host = host.to_s.strip
    end

    def as_json(*)
      {
        ok: true,
        host: host,
        heartbeat: serialize_heartbeat(heartbeat),
        logs: logs.map { |log| serialize_log(log) }
      }
    end

    private

    attr_reader :host

    def heartbeat
      @heartbeat ||= KioskHeartbeat.find_by(kiosk_id: host)
    end

    def logs
      @logs ||= KioskLog
        .where(kiosk_id: host)
        .order(occurred_at: :desc)
        .limit(LOG_LIMIT)
        .select(:occurred_at, :level, :message, :raw_payload)
    end

    def serialize_heartbeat(heartbeat)
      return nil unless heartbeat

      raw_payload = heartbeat.raw_payload.is_a?(Hash) ? heartbeat.raw_payload : {}

      {
        kiosk_id: heartbeat.kiosk_id,
        last_seen_at: heartbeat.last_seen_at,
        uptime_seconds: heartbeat.uptime_seconds,
        kiosk_service: heartbeat.kiosk_service,
        chromium_pids: heartbeat.chromium_pids,
        chromium_devtools_ok: raw_payload["chromium_devtools_ok"],
        chromium_devtools_http: raw_payload["chromium_devtools_http"],
        chromium_devtools_ms: raw_payload["chromium_devtools_ms"]
      }
    end

    def serialize_log(log)
      event, envelope, request_meta = extract_event_and_envelope(log.raw_payload)

      {
        occurred_at: log.occurred_at,
        level: log.level,
        message: log.message,
        kind: event["kind"],
        tab_url: event["tab_url"],
        href: event["href"],
        source: event["source"],
        lineno: event["lineno"],
        colno: event["colno"],
        stack: event["stack"],
        tab_id: event["tab_id"],
        sent_at: envelope["sent_at"],
        envelope_ts: envelope["ts"],
        remote_ip: request_meta["remote_ip"],
        user_agent: request_meta["user_agent"]
      }
    end

    # Supports both the current envelope/event payload and legacy rows where
    # raw_payload was the browser event itself.
    def extract_event_and_envelope(raw_payload)
      raw_payload = raw_payload.is_a?(Hash) ? raw_payload : {}

      if raw_payload.key?("event") || raw_payload.key?("envelope")
        event = raw_payload["event"].is_a?(Hash) ? raw_payload["event"] : {}
        envelope = raw_payload["envelope"].is_a?(Hash) ? raw_payload["envelope"] : {}
        request_meta = raw_payload["request"].is_a?(Hash) ? raw_payload["request"] : {}
        [event, envelope, request_meta]
      else
        [raw_payload, {}, {}]
      end
    end
  end
end
