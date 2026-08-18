# app/helpers/application_helper.rb
require 'net/http'
require 'json'

module ApplicationHelper
  LOCATIONS_CACHE_KEY = "kiosk-dashboard/locations/v1"
  LOCATIONS_CACHE_TTL = 15.minutes

  def locations_data
    cached = Rails.cache.read(LOCATIONS_CACHE_KEY)
    return cached[:locations] if cached && cached[:fetched_at] > LOCATIONS_CACHE_TTL.ago

    locations = fetch_locations_data
    Rails.cache.write(LOCATIONS_CACHE_KEY, { locations: locations, fetched_at: Time.current })
    locations
  rescue => e
    Rails.logger.warn("Could not load location data: #{e}")
    cached&.fetch(:locations, []) || []
  end

  def location_for_group(group)
    identifier = group&.respond_to?(:location_shortname) ? group.location_shortname.presence : nil
    identifier ||= group&.slug
    locations_data.find { |location| location["shortname"] == identifier }
  end

  def open_minutes_for_range(location, start_date, end_date)
    days = (start_date..end_date).to_a
    days.sum do |date|
      weekday = date.strftime('%A').downcase
      hours_str = location[weekday]
      parse_open_minutes(hours_str)
    end
  end

  def parse_open_minutes(hours_str)
    return 0 if hours_str.blank? || hours_str.downcase.include?('closed')
    start_time, end_time = hours_str.split(' to ')
    # Fix "Noon" for parsing
    start_time = start_time.gsub(/\bNoon\b/i, "12:00 PM") if start_time
    end_time   = end_time.gsub(/\bNoon\b/i, "12:00 PM") if end_time
    t1 = Time.zone.parse(start_time)
    t2 = Time.zone.parse(end_time)
    return 0 unless t1 && t2
    ((t2 - t1) / 60).to_i
  rescue => e
    Rails.logger.warn("ERROR parse_open_minutes(#{hours_str.inspect}): #{e}")
    0
  end

  # Human readable duration from seconds.
  # Uses fixed conversions: 1y=365d, 1mo=30d, 1w=7d.
  def human_duration(total_seconds)
    secs = total_seconds.to_i
    return "0s" if secs <= 0

    units = [
      ["y",  365 * 24 * 60 * 60],
      ["mo", 30  * 24 * 60 * 60],
      ["w",  7   * 24 * 60 * 60],
      ["d",  24  * 60 * 60],
      ["h",  60  * 60],
      ["m",  60],
      ["s",  1]
    ]

    parts = []
    units.each do |label, size|
      next if secs < size
      q, secs = secs.divmod(size)
      parts << "#{q}#{label}"
    end

    parts.join(" ")
  end

  def kiosk_usage_presets(today = Date.current)
    {
      "today" => (today..today),
      "yesterday" => ((today - 1.day)..(today - 1.day)),
      "last_7_days" => ((today - 6.days)..today),
      "last_30_days" => ((today - 29.days)..today),
      "current_month" => (today.beginning_of_month..today),
      "previous_month" => ((today - 1.month).beginning_of_month..(today - 1.month).end_of_month),
      "current_year" => (today.beginning_of_year..today),
      "previous_year" => (today.last_year.beginning_of_year..today.last_year.end_of_year)
    }
  end

  def date_range_value(range)
    "#{range.begin}|#{range.end}"
  end

  def safe_date_param(value, fallback)
    value.present? ? Date.parse(value) : fallback
  rescue ArgumentError, TypeError
    fallback
  end

  def kiosk_usage_date_range(start_value, end_value, fallback, max_days: 366)
    start_date = safe_date_param(start_value, fallback.begin)
    end_date = safe_date_param(end_value, fallback.end)
    return fallback if start_date > end_date
    return fallback if (end_date - start_date).to_i >= max_days

    start_date..end_date
  rescue Date::Error, RangeError
    fallback
  end

  def kiosk_usage_chart_payload(sessions, start_date, end_date)
    sessions = Array(sessions)
    range_start = start_date.beginning_of_day
    range_end = [end_date.end_of_day, Time.current].min
    session_starts = sessions.filter_map do |session|
      next if session.started_at > range_end
      next unless session.duration_within(range_start, range_end).positive?

      [session.started_at, range_start].max
    end

    if start_date == end_date
      hours = (0..23).to_a
      {
        labels: hours.map { |hour| "#{hour}:00" },
        data: hours.map { |hour| session_starts.count { |started_at| started_at.hour == hour && started_at.to_date == start_date } }
      }
    else
      days = (start_date..end_date).to_a
      {
        labels: days.map { |day| day.strftime("%b %-d") },
        data: days.map { |day| session_starts.count { |started_at| started_at.to_date == day } }
      }
    end
  end

  def kiosk_usage_host_stats(host_sessions, start_date, end_date, group_obj = nil)
    range_start = start_date.beginning_of_day
    range_end = [end_date.end_of_day, Time.current].min
    durations = host_sessions.map { |session| session.duration_within(range_start, range_end) }.select(&:positive?)
    total_min = durations.any? ? (durations.sum / 60.0) : 0

    group_obj ||= host_sessions.first&.kiosk&.kiosk_group
    location = group_obj && location_for_group(group_obj)
    open_min = location ? open_minutes_for_range(location, start_date, end_date) : nil
    util_pct = (open_min && open_min > 0) ? (total_min / open_min * 100).round(1) : nil

    {
      count: host_sessions.count,
      first_started_at: host_sessions.map(&:started_at).min,
      last_ended_at: host_sessions.map(&:ended_at).compact.max,
      utilization_percent: util_pct,
      average_minutes: durations.any? ? (durations.sum / durations.size / 60).round(1) : nil,
      total_minutes: durations.any? ? total_min.round(1) : nil
    }
  end


  private

  def fetch_locations_data
    uri = URI.parse(ENV.fetch("LOCATION_DATA_URL"))
    raise URI::InvalidURIError, "location URL must be HTTP(S)" unless uri.is_a?(URI::HTTP) && uri.host.present?

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.is_a?(URI::HTTPS)
    http.open_timeout = 2
    http.read_timeout = 3

    response = http.request(Net::HTTP::Get.new(uri.request_uri))
    raise "location request returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    locations = JSON.parse(response.body).fetch("locations")
    raise "location response must contain an array" unless locations.is_a?(Array)

    locations
  end
end
