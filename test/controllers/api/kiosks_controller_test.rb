require "test_helper"

class Api::KiosksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_psk = ENV["KIOSK_API_PSK"]
    ENV["KIOSK_API_PSK"] = "test-kiosk-key"
    @headers = {
      "CONTENT_TYPE" => "application/json",
      "X-Kiosk-Key" => "test-kiosk-key"
    }
  end

  teardown do
    ENV["KIOSK_API_PSK"] = @previous_psk
  end

  test "rejects non-object payloads" do
    post api_kiosks_logs_url, params: [].to_json, headers: @headers

    assert_response :bad_request
    assert_equal "JSON payload must be an object", response.parsed_body["error"]
  end

  test "rejects requests without the shared key" do
    post api_kiosks_heartbeat_url,
      params: { kiosk_id: "nucpac01" }.to_json,
      headers: @headers.except("X-Kiosk-Key")

    assert_response :unauthorized
    assert_not KioskHeartbeat.exists?(kiosk_id: "nucpac01")
  end

  test "requires matching valid kiosk identifiers" do
    post api_kiosks_logs_url,
      params: { kiosk_id: "nucpac01", events: [] }.to_json,
      headers: @headers.merge("X-Kiosk-Id" => "nucpac02")

    assert_response :bad_request
    assert_equal "X-Kiosk-Id does not match kiosk_id", response.parsed_body["error"]

    post api_kiosks_heartbeat_url,
      params: { kiosk_id: "bad kiosk" }.to_json,
      headers: @headers

    assert_response :bad_request
    assert_equal "invalid kiosk_id", response.parsed_body["error"]
  end

  test "rejects oversized payloads without ingesting logs" do
    body = { kiosk_id: "nucpac01", padding: "x" * (Api::KiosksController::MAX_BODY_BYTES + 1) }.to_json

    post api_kiosks_logs_url, params: body, headers: @headers

    assert_response :content_too_large
    assert_equal 0, KioskLog.where(kiosk_id: "nucpac01").count
  end

  test "accepts authenticated heartbeat payloads" do
    post api_kiosks_heartbeat_url,
      params: {
        kiosk_id: "nucpac01",
        ts: Time.current.iso8601,
        kiosk_service: "running",
        wireguard_enabled: true,
        wireguard_ip_address: "10.73.73.24",
        wireguard_status: "healthy",
        wireguard_latest_handshake_at: 1_777_891_200,
        wireguard_handshake_age_seconds: 20
      }.to_json,
      headers: @headers

    assert_response :success
    heartbeat = KioskHeartbeat.find_by!(kiosk_id: "nucpac01")
    assert_equal "running", heartbeat.kiosk_service
    assert_equal "10.73.73.24", heartbeat.raw_payload["wireguard_ip_address"]
    assert_equal "healthy", heartbeat.raw_payload["wireguard_status"]
  end

  test "records an online notice only once across heartbeat retries" do
    payload = {
      kiosk_id: "nucpac01",
      ts: Time.current.iso8601,
      private_ip_address: "192.0.2.15",
      online_notice: "Kiosk online with private IP address 192.0.2.15"
    }

    2.times do
      post api_kiosks_heartbeat_url, params: payload.to_json, headers: @headers
      assert_response :success
      assert_equal true, response.parsed_body["online_notice_recorded"]
    end

    heartbeat = KioskHeartbeat.find_by!(kiosk_id: "nucpac01")
    notices = KioskLog.where(kiosk_id: "nucpac01", message: payload[:online_notice])

    assert_equal "192.0.2.15", heartbeat.raw_payload["private_ip_address"]
    assert_equal 1, notices.count
    assert_equal "kiosk_online", notices.first.raw_payload.dig("event", "kind")
  end
end
