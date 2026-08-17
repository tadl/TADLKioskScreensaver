# app/models/host.rb
class Host < ApplicationRecord
  NAME_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9._-]*\z/

  validates :name,
    presence: true,
    uniqueness: true,
    length: { maximum: 253 },
    format: { with: NAME_FORMAT }

  # Link to existing string "host" columns (no schema change needed)
  has_many :kiosk_statuses,
           primary_key: :name,
           foreign_key: :host,
           dependent: :destroy

  has_many :kiosk_sessions,
           primary_key: :name,
           foreign_key: :host,
           dependent: :destroy

  def to_s
    name
  end
end
