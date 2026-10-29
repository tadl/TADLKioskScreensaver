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

  test "invalid heartbeat timestamps use receipt time" do
    freeze_time do
      post api_kiosks_heartbeat_url,
        params: { kiosk_id: "timestamp-host", ts: "nonsense" }.to_json,
        headers: @headers

      assert_response :success
      assert_equal Time.current, KioskHeartbeat.find_by!(kiosk_id: "timestamp-host").last_seen_at
    end
  end

  test "heartbeats accept explicit counts and legacy PID list formats" do
    [
      [{ chromium_pid_count: 7 }, 7],
      [{ chromium_pid_count: "8", chromium_pids: "101 102" }, 8],
      [{ chromium_pids: 9 }, 9],
      [{ chromium_pids: "101 102 103" }, 3],
      [{ chromium_pids: [101, 102] }, 2],
      [{ chromium_pids: [] }, 0]
    ].each do |attributes, expected|
      post api_kiosks_heartbeat_url,
        params: attributes.merge(kiosk_id: "pid-count-host").to_json, headers: @headers

      assert_response :success
      assert_equal expected, KioskHeartbeat.find_by!(kiosk_id: "pid-count-host").chromium_pids
    end
  end

  test "invalid Chromium counts return a client error without changing the heartbeat" do
    heartbeat = KioskHeartbeat.create!(kiosk_id: "pid-count-host", last_seen_at: 1.minute.ago, chromium_pids: 3)

    [{ chromium_pid_count: {} }, { chromium_pid_count: -1 }, { chromium_pid_count: 2**31 }, { chromium_pids: {} }].each do |attributes|
      post api_kiosks_heartbeat_url,
        params: attributes.merge(kiosk_id: heartbeat.kiosk_id).to_json, headers: @headers

      assert_response :bad_request
      assert_equal 3, heartbeat.reload.chromium_pids
    end
  end

  test "invalid log timestamps use receipt time" do
    freeze_time do
      post api_kiosks_logs_url,
        params: { kiosk_id: "timestamp-host", ts: "nonsense", events: [{ ts: "nonsense", message: "test" }] }.to_json,
        headers: @headers

      assert_response :success
      assert_equal Time.current, KioskLog.find_by!(kiosk_id: "timestamp-host").occurred_at
    end
  end
end
