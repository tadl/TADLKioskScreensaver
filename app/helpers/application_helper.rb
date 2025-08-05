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
end
