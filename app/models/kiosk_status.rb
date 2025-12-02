# frozen_string_literal: true

class KioskStatus < ApplicationRecord
  belongs_to :kiosk

  enum state: { screensaver: 0, opac: 1 }

  validates :host, presence: true
  validates :state, presence: true
  validates :state_changed_at, presence: true

  # Simple helper for readable durations if you need it later
  def state_duration_label(now = Time.current)
    seconds = (now - state_changed_at).to_i
    h = seconds / 3600
    m = (seconds % 3600) / 60
    h.positive? ? format("%dh%02dm", h, m) : format("%dm", m)
  end
end
