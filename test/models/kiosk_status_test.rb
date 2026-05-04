require "test_helper"

class KioskStatusTest < ActiveSupport::TestCase
  test "mark creates and updates kiosk status" do
    kiosk = kiosks(:one)
    host = "status-host-01"
    first_seen = 10.minutes.ago
    second_seen = 2.minutes.ago

    status = KioskStatus.mark!(kiosk: kiosk, host: host, state: :screensaver, now: first_seen)

    assert_equal kiosk, status.kiosk
    assert_equal host, status.host
    assert_equal "screensaver", status.state
    assert_equal first_seen.to_i, status.state_changed_at.to_i

    KioskStatus.mark!(kiosk: kiosk, host: host, state: :opac, now: second_seen)

    status.reload
    assert_equal "opac", status.state
    assert_equal second_seen.to_i, status.state_changed_at.to_i
  end

  test "mark refreshes screensaver timestamp when state is unchanged" do
    kiosk = kiosks(:one)
    host = "status-host-02"
    first_seen = 10.minutes.ago
    second_seen = 1.minute.ago

    status = KioskStatus.mark!(kiosk: kiosk, host: host, state: :screensaver, now: first_seen)
    KioskStatus.mark!(kiosk: kiosk, host: host, state: :screensaver, now: second_seen)

    assert_equal second_seen.to_i, status.reload.state_changed_at.to_i
  end
end
