# app/helpers/application_helper.rb
require 'net/http'
require 'json'

module ApplicationHelper
  # Class variable cache (simple)
  @@locations_cache = nil
  @@locations_cache_time = nil

  def locations_data
    if @@locations_cache && @@locations_cache_time && Time.now - @@locations_cache_time < 15.minutes
      @@locations_cache
    else
      url = ENV.fetch("LOCATION_DATA_URL")
      resp = Net::HTTP.get(URI(url))
      @@locations_cache = JSON.parse(resp)["locations"]
      @@locations_cache_time = Time.now
      @@locations_cache
    end
  rescue => e
    Rails.logger.warn("Could not load location data: #{e}")
    []
  end

  def location_for_group_slug(slug)
    locations_data.find { |loc| loc["shortname"] == slug }
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
      next if session.ended_at && session.ended_at < range_start

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
    location = group_obj&.slug && location_for_group_slug(group_obj.slug)
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
end
