# frozen_string_literal: true

class KioskLog < ApplicationRecord
  validates :kiosk_id, :occurred_at, presence: true
end
