require "test_helper"

class HostTest < ActiveSupport::TestCase
  test "deleting a host clears live status and preserves historical usage" do
    host = Host.create!(name: "retired-host")
    kiosk = kiosks(:one)
    session = KioskSession.create!(
      kiosk_code: kiosk.slug,
      host: host.name,
      started_at: 1.hour.ago,
      ended_at: 30.minutes.ago
    )
    status = KioskStatus.mark!(kiosk: kiosk, host: host.name, state: :screensaver)

    host.destroy!

    assert_not Host.exists?(host.id)
    assert_not KioskStatus.exists?(status.id)
    assert_equal "retired-host", session.reload.host
    assert_equal kiosk, session.kiosk
  end
end
