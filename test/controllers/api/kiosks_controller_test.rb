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
      params: { kiosk_id: "nucpac01", ts: Time.current.iso8601, kiosk_service: "running" }.to_json,
      headers: @headers

    assert_response :success
    assert_equal "running", KioskHeartbeat.find_by!(kiosk_id: "nucpac01").kiosk_service
  end
end
