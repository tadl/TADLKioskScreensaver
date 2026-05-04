require "test_helper"

class Admin::KioskHostDetailsTest < ActiveSupport::TestCase
  test "serializes heartbeat and recent logs for a host" do
    host = "detail-host-01"
    KioskHeartbeat.create!(
      kiosk_id: host,
      last_seen_at: Time.zone.parse("2026-05-04 12:00:00"),
      uptime_seconds: 120,
      kiosk_service: "running",
      chromium_pids: 3,
      raw_payload: {
        "chromium_devtools_ok" => true,
        "chromium_devtools_http" => 200,
        "chromium_devtools_ms" => 12
      }
    )
    KioskLog.create!(
      kiosk_id: host,
      occurred_at: Time.zone.parse("2026-05-04 12:01:00"),
      level: "info",
      message: "Loaded",
      raw_payload: {
        "event" => { "kind" => "browser", "tab_url" => "https://example.com" },
        "envelope" => { "sent_at" => "2026-05-04T12:01:30Z" },
        "request" => { "remote_ip" => "127.0.0.1" }
      }
    )

    details = Admin::KioskHostDetails.new(host).as_json

    assert_equal true, details[:ok]
    assert_equal host, details[:host]
    assert_equal "running", details[:heartbeat][:kiosk_service]
    assert_equal "browser", details[:logs].first[:kind]
    assert_equal "https://example.com", details[:logs].first[:tab_url]
  end
end
