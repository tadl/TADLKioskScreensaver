# app/models/host.rb
class Host < ApplicationRecord
  validates :name, presence: true, uniqueness: true

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
