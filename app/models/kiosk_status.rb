# frozen_string_literal: true

class KioskStatus < ApplicationRecord
  belongs_to :kiosk

  enum state: { screensaver: 0, opac: 1 }

  validates :host, presence: true
  validates :state, presence: true
  validates :state_changed_at, presence: true

  # Records the state shown on the dashboard. Re-entering screensaver refreshes
  # state_changed_at so reboot/direct-load events reset the idle timer.
  def self.mark!(kiosk:, host:, state:, now: Time.zone.now)
    return unless kiosk && host.present?

    new_state = state.to_s
    status = find_or_initialize_by(kiosk: kiosk, host: host)

    if status.new_record? || status.state != new_state
      status.state = new_state
      status.state_changed_at = now
    elsif new_state == "screensaver"
      status.state_changed_at = now
    end

    status.save! if status.changed?
    status
  rescue StandardError => e
    Rails.logger.warn(
      "[KioskStatus] mark failed for kiosk=#{kiosk&.id} host=#{host} state=#{state}: " \
      "#{e.class}: #{e.message}"
    )
    nil
  end

  # Simple helper for readable durations if you need it later
  def state_duration_label(now = Time.current)
    seconds = (now - state_changed_at).to_i
    h = seconds / 3600
    m = (seconds % 3600) / 60
    h.positive? ? format("%dh%02dm", h, m) : format("%dm", m)
  end
end
