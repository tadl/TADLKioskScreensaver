# app/models/kiosk_session.rb
class KioskSession < ApplicationRecord
  def kiosk
    Kiosk.find_by(slug: kiosk_code)
  end

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
