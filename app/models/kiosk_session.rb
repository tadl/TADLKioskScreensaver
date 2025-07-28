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
end
