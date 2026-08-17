require "test_helper"

class KioskLogIngestorTest < ActiveSupport::TestCase
  test "inserts normalized log rows from batch payload" do
    now = Time.zone.parse("2026-05-04 12:00:00")
    payload = {
      "kiosk_id" => "nucpac01",
      "sent_at" => "2026-05-04T11:59:00Z",
      "events" => [
        {
          "ts" => "2026-05-04T11:58:00Z",
          "level" => "error",
          "kind" => "browser",
          "message" => "Boom",
          "tab_url" => "https://example.com"
        }
      ]
    }

    inserted = KioskLogIngestor.new(
      payload: payload,
      kiosk_id: "nucpac01",
      request_meta: { "remote_ip" => "127.0.0.1", "user_agent" => "test" },
      now: now
    ).insert!

    assert_equal 1, inserted
    log = KioskLog.order(:id).last
    assert_equal "nucpac01", log.kiosk_id
    assert_equal "error", log.level
    assert_equal "[browser] Boom", log.message
    assert_equal "https://example.com", log.raw_payload.dig("event", "tab_url")
    assert_equal "127.0.0.1", log.raw_payload.dig("request", "remote_ip")
  end

  test "limits batch inserts to prevent runaway clients" do
    payload = {
      "events" => Array.new(KioskLogIngestor::MAX_EVENTS + 1) { |i| { "message" => "event #{i}" } }
    }

    inserted = KioskLogIngestor.new(
      payload: payload,
      kiosk_id: "nucpac02",
      request_meta: {},
      now: Time.current
    ).insert!

    assert_equal KioskLogIngestor::MAX_EVENTS, inserted
  end

  test "bounds raw event fields and discards unknown fields" do
    payload = {
      "events" => [{
        "message" => "m" * 5_000,
        "stack" => "s" * 25_000,
        "unknown" => "not stored"
      }]
    }

    KioskLogIngestor.new(
      payload: payload,
      kiosk_id: "nucpac03",
      request_meta: {},
      now: Time.current
    ).insert!

    event = KioskLog.order(:id).last.raw_payload.fetch("event")
    assert_equal KioskLogIngestor::MAX_MESSAGE_LENGTH, event.fetch("message").length
    assert_equal KioskLogIngestor::MAX_STACK_LENGTH, event.fetch("stack").length
    assert_not event.key?("unknown")
  end
end
