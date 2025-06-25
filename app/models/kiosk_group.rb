# frozen_string_literal: true

class KioskGroup < ApplicationRecord
  has_many :kiosks

  has_and_belongs_to_many :user_permissions

  validates :name, presence: true
  validates :slug,
            presence: true,
            uniqueness: true,
            format: { with: /\A[a-z0-9\-]+\z/,
                      message: "only lowercase, numbers, hyphens" }
end

