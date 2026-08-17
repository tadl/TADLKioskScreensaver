require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "rejects reversed and excessively large usage ranges" do
    fallback = (Date.new(2026, 7, 1)..Date.new(2026, 7, 30))

    assert_equal fallback, kiosk_usage_date_range("2026-08-01", "2026-07-01", fallback)
    assert_equal fallback, kiosk_usage_date_range("2020-01-01", "2026-01-01", fallback)
  end

  test "clips session durations to the requested range" do
    range_start = Time.zone.parse("2026-08-10 00:00:00")
    range_end = Time.zone.parse("2026-08-10 23:59:59")
    kiosk_session = KioskSession.new(
      started_at: range_start - 1.hour,
      ended_at: range_start + 2.hours
    )

    assert_equal 2.hours, kiosk_session.duration_within(range_start, range_end, now: range_end)
  end
end
