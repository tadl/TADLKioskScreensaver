require "test_helper"

class Admin::UsageReportTest < ActiveSupport::TestCase
  test "a group filter cannot expand direct kiosk access" do
    group = KioskGroup.create!(name: "Test group", slug: "test-group")
    group.kiosks = [kiosks(:one), kiosks(:two)]
    actor = users(:two)
    actor.user_permissions.first.kiosks << kiosks(:one)
    [kiosks(:one), kiosks(:two)].each do |kiosk|
      KioskSession.create!(kiosk_code: kiosk.slug, host: "test-#{kiosk.slug}", started_at: 1.hour.ago, ended_at: 10.minutes.ago)
    end
    report = Admin::UsageReport.new(user: actor, params: { kiosk_group: group.id.to_s }, helpers: ApplicationController.helpers)
    assert_equal [kiosks(:one).slug], report.sessions.map(&:kiosk_code)
  end

  test "invalid ranges fall back without hiding historical sessions from deleted kiosks for administrators" do
    usage = KioskSession.create!(kiosk_code: "deleted-kiosk", host: "historical-host", started_at: 1.hour.ago, ended_at: 10.minutes.ago)
    report = Admin::UsageReport.new(user: users(:one), params: { start: "2020-01-01", end: "2099-01-01" }, helpers: ApplicationController.helpers)
    assert_equal ((Date.current - 29)..Date.current), report.date_range
    assert_includes report.sessions, usage
    assert_nil report.grouped.first.first
  end
end
