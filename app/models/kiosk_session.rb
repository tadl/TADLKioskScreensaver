# app/models/kiosk_session.rb
class KioskSession < ApplicationRecord
  # Associates kiosk_sessions.kiosk_code => kiosks.slug
  belongs_to :kiosk, primary_key: :slug, foreign_key: :kiosk_code, optional: true

  # Convenience methods
  def kiosk_group
    kiosk&.kiosk_group
  end

  def location_shortname
    kiosk_group&.location_shortname
  end

  def session_duration
    return nil unless ended_at && started_at
    ended_at - started_at
  end

  def duration_within(range_start, range_end, now: Time.current)
    effective_start = [started_at, range_start].max
    effective_end = [ended_at || now, range_end, now].min
    return 0 if effective_end <= effective_start

    effective_end - effective_start
  end
end
