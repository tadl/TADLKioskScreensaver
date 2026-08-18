# app/models/kiosk_session.rb
class KioskSession < ApplicationRecord
  MAX_DURATION = 12.hours

  scope :overlapping, ->(range_start, range_end) {
    where("started_at <= ?", range_end)
      .where(
        "started_at > :duration_cutoff AND (ended_at IS NULL OR ended_at > :range_start)",
        range_start: range_start,
        duration_cutoff: range_start - MAX_DURATION
      )
  }
  scope :stale_open, ->(now = Time.current) {
    where(ended_at: nil).where("started_at < ?", now - MAX_DURATION)
  }

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
    effective_end = [effective_ended_at(now: now), range_end, now].min
    return 0 if effective_end <= effective_start

    effective_end - effective_start
  end

  def effective_ended_at(now: Time.current)
    [ended_at || now, started_at + MAX_DURATION, now].min
  end

  def self.close_stale!(now: Time.current, kiosk_code: nil, host: nil)
    relation = stale_open(now)
    relation = relation.where(kiosk_code: kiosk_code) if kiosk_code.present?
    relation = relation.where(host: host) if host.present?

    relation.update_all(
      sanitize_sql_array([
        "ended_at = started_at + (? * INTERVAL '1 second'), updated_at = ?",
        MAX_DURATION.to_i,
        now
      ])
    )
  end
end
