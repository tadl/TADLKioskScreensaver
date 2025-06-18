class Kiosk < ApplicationRecord
  belongs_to :kiosk_group, optional: true
  has_and_belongs_to_many :slides

  validates :name,        presence: true
  validates :slug,        presence: true, uniqueness: true,
                          format: { with: /\A[a-z0-9\-]+\z/ }
  validates :catalog_url, presence: true,
                          format: { with: /\Ahttps?:\/\// }
end

