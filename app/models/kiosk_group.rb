# frozen_string_literal: true

class KioskGroup < ApplicationRecord
  has_many :kiosks

  validates :name, presence: true
  validates :slug,
            presence: true,
            uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/,
                      message: "only lowercase, numbers, hyphens" }
end

