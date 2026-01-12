# frozen_string_literal: true

class KioskHeartbeat < ApplicationRecord
  validates :kiosk_id, presence: true, uniqueness: true
  validates :last_seen_at, presence: true
end
