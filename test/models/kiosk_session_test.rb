require "test_helper"

class KioskSessionTest < ActiveSupport::TestCase
  test "caps abandoned open sessions at twelve hours" do
    started_at = Time.zone.parse("2025-11-24 13:06:00")
    session = KioskSession.new(started_at: started_at)

    assert_equal 12.hours, session.duration_within(started_at, started_at + 1.year, now: started_at + 1.year)
  end

  test "overlapping excludes old open sessions from a current range" do
    range_start = Time.zone.parse("2026-07-20 00:00:00")
    range_end = Time.zone.parse("2026-08-18 23:59:59")
    stale = KioskSession.create!(
      kiosk_code: kiosks(:one).slug,
      host: "old-open-host",
      started_at: Time.zone.parse("2025-11-24 13:06:00")
    )
    recent = KioskSession.create!(
      kiosk_code: kiosks(:one).slug,
      host: "recent-open-host",
      started_at: range_end - 1.hour
    )

    sessions = KioskSession.overlapping(range_start, range_end)

    assert_not_includes sessions, stale
    assert_includes sessions, recent
  end

  test "overlapping excludes an implausibly long completed session" do
    range_start = Time.zone.parse("2026-07-20 00:00:00")
    range_end = Time.zone.parse("2026-08-18 23:59:59")
    session = KioskSession.create!(
      kiosk_code: kiosks(:one).slug,
      host: "old-completed-host",
      started_at: Time.zone.parse("2025-12-02 12:59:00"),
      ended_at: range_end - 1.hour
    )

    assert_not_includes KioskSession.overlapping(range_start, range_end), session
    assert_equal 12.hours, session.duration_within(session.started_at, range_end, now: range_end)
  end

  test "close stale records their capped end without closing recent sessions" do
    now = Time.zone.parse("2026-08-18 12:00:00")
    stale = KioskSession.create!(
      kiosk_code: kiosks(:one).slug,
      host: "stale-host",
      started_at: now - 2.days
    )
    recent = KioskSession.create!(
      kiosk_code: kiosks(:one).slug,
      host: "recent-host",
      started_at: now - 1.hour
    )

    assert_equal 1, KioskSession.close_stale!(now: now)
    assert_equal stale.started_at + 12.hours, stale.reload.ended_at
    assert_nil recent.reload.ended_at
  end
end
