class Kiosk < ApplicationRecord
  belongs_to :kiosk_group, optional: true
  has_and_belongs_to_many :slides

  validates :name,        presence: true
  validates :slug,        presence: true, uniqueness: true,
                          format: { with: /\A[a-z0-9\-]+\z/ }
  validates :catalog_url, presence: true
  validate :catalog_url_must_have_http_host

  def slides_count
    slides.size
  end

  private

  def catalog_url_must_have_http_host
    return if catalog_url.blank?

    uri = URI.parse(catalog_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    errors.add(:catalog_url, "must be an HTTP or HTTPS URL with a host")
  rescue URI::InvalidURIError
    errors.add(:catalog_url, "must be an HTTP or HTTPS URL with a host")
  end
end
