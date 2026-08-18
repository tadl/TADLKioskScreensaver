require "test_helper"

class MaintenanceTasksTest < ActiveSupport::TestCase
  test "expire task removes expired slides from kiosks without deleting them" do
    load_rake_task("slides:expire", "expire_slides")
    slide = create_slide_with_image!(
      title: "Expired Assignment",
      start_date: 30.days.ago.to_date,
      end_date: 1.day.ago.to_date
    )
    kiosk = kiosks(:one)
    kiosk.slides << slide

    capture_io { Rake::Task["slides:expire"].invoke }

    assert Slide.exists?(slide.id)
    assert_not kiosk.slides.reload.exists?(slide.id)
  end

  test "log purge task removes only rows outside retention" do
    load_rake_task("kiosk_logs:purge_old", "kiosk_logs")
    old_log = KioskLog.create!(
      kiosk_id: "maintenance-host",
      occurred_at: 181.days.ago,
      message: "old"
    )
    recent_log = KioskLog.create!(
      kiosk_id: "maintenance-host",
      occurred_at: 179.days.ago,
      message: "recent"
    )

    capture_io { Rake::Task["kiosk_logs:purge_old"].invoke }

    assert_not KioskLog.exists?(old_log.id)
    assert KioskLog.exists?(recent_log.id)
  end

  test "session cleanup closes abandoned open sessions" do
    load_rake_task("kiosk_sessions:close_stale", "kiosk_sessions")
    session = KioskSession.create!(
      kiosk_code: kiosks(:one).slug,
      host: "task-stale-host",
      started_at: 2.days.ago
    )

    capture_io { Rake::Task["kiosk_sessions:close_stale"].invoke }

    assert_equal session.started_at + 12.hours, session.reload.ended_at
  end
end
