# frozen_string_literal: true

class KioskLogIngestor
  MAX_EVENTS = 500
  MAX_MESSAGE_LENGTH = 4000
  MAX_STACK_LENGTH = 20_000
  MAX_URL_LENGTH = 2_048
  EVENT_KEYS = %w[ts occurred_at level kind message tab_url href source lineno colno stack tab_id].freeze
  ENVELOPE_KEYS = %w[kiosk_id host ts sent_at version].freeze

  def initialize(payload:, kiosk_id:, request_meta:, now: Time.zone.now)
    @payload = payload.is_a?(Hash) ? payload : {}
    @kiosk_id = kiosk_id
    @request_meta = request_meta
    @now = now
  end

  def insert!
    rows = build_rows
    KioskLog.insert_all!(rows) if rows.any?
    rows.size
  end

  private

  attr_reader :payload, :kiosk_id, :request_meta, :now

  def build_rows
    events.map do |event|
      event = event.is_a?(Hash) ? event : { "message" => event.to_s }

      {
        kiosk_id: kiosk_id,
        occurred_at: occurred_at_for(event),
        level: event["level"].to_s.presence,
        message: message_for(event),
        raw_payload: {
          "envelope" => envelope,
          "event" => sanitized_event(event),
          "request" => request_meta
        },
        created_at: now,
        updated_at: now
      }
    end
  end

  def events
    source = payload["events"].is_a?(Array) ? payload["events"] : [payload]
    source.first(MAX_EVENTS)
  end

  def envelope
    @envelope ||= payload.slice(*ENVELOPE_KEYS).transform_values { |value| bounded_value(value, 1_000) }
  end

  def occurred_at_for(event)
    parse_time(event["ts"] || event["occurred_at"]) ||
      parse_time(envelope["ts"] || envelope["sent_at"]) ||
      now
  end

  def message_for(event)
    kind = event["kind"].to_s.presence
    event_message = event["message"].to_s.presence
    message = if kind.present? && event_message
      "[#{kind}] #{event_message}"
    else
      event_message || kind || "(no message)"
    end

    message.to_s.first(MAX_MESSAGE_LENGTH)
  end

  def parse_time(value)
    return nil if value.blank?

    parsed = Time.zone.parse(value.to_s)
    return nil if parsed < 1.year.ago || parsed > 1.day.from_now

    parsed
  rescue ArgumentError, TypeError
    nil
  end

  def sanitized_event(event)
    event.slice(*EVENT_KEYS).to_h do |key, value|
      limit = case key
      when "stack" then MAX_STACK_LENGTH
      when "tab_url", "href", "source" then MAX_URL_LENGTH
      when "message" then MAX_MESSAGE_LENGTH
      else 1_000
      end
      [key, bounded_value(value, limit)]
    end
  end

  def bounded_value(value, limit)
    case value
    when String then value.first(limit)
    when Numeric, TrueClass, FalseClass, NilClass then value
    else value.to_s.first(limit)
    end
  end
end
