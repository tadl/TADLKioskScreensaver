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

  test "uses the group's location shortname for location data" do
    group = KioskGroup.new(slug: "display-name", location_shortname: "woodmere")
    @locations_data = [{ "shortname" => "woodmere", "monday" => "9:00 AM to 5:00 PM" }]

    assert_equal @locations_data.first, location_for_group(group)
  end

  test "location feed failures are cached between dashboard requests and retried later" do
    cache = ActiveSupport::Cache::MemoryStore.new
    attempts = 0
    fetch = lambda do
      attempts += 1
      raise IOError, "synthetic feed outage" if attempts == 1
      [{ "shortname" => "example" }]
    end

    previous_cache = Rails.cache
    Rails.cache = cache
    define_singleton_method(:fetch_locations_data, &fetch)

    assert_empty locations_data
    assert_empty locations_data
    @locations_data = nil
    assert_empty locations_data
    assert_equal 1, attempts

    travel 61.seconds do
      @locations_data = nil
      assert_equal [{ "shortname" => "example" }], locations_data
      assert_equal 2, attempts
    end
  ensure
    Rails.cache = previous_cache
  end

  test "a failed location refresh preserves the last good data" do
    cache = ActiveSupport::Cache::MemoryStore.new
    previous = [{ "shortname" => "example", "monday" => "9:00 AM to 5:00 PM" }]
    cache.write(ApplicationHelper::LOCATIONS_CACHE_KEY, locations: previous, fetched_at: 1.hour.ago)
    attempts = 0

    previous_cache = Rails.cache
    Rails.cache = cache
    define_singleton_method(:fetch_locations_data) { attempts += 1; raise IOError, "synthetic feed outage" }

    assert_equal previous, locations_data
    @locations_data = nil
    assert_equal previous, locations_data
    assert_equal 1, attempts
  ensure
    Rails.cache = previous_cache
  end

  def locations_data
    @locations_data || super
  end
end
