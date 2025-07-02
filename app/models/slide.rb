# frozen_string_literal: true

class Slide < ApplicationRecord
  has_and_belongs_to_many :kiosks
  has_one_attached :image

  # Auto-set title and duration defaults before validation
  before_validation :set_default_title
  before_validation :set_default_display_seconds
  before_validation :set_default_start_date, on: :create

  # Core validations
  validates :title, presence: true
  validates :display_seconds,
            numericality: { only_integer: true, greater_than: 0 }
  validate  :start_date_before_end_date

  scope :fallbacks, -> { where(fallback: true) }

  # Helper to check whether the image is exactly 1920×1080,
  # without raising a validation error on save
  def valid_dimensions?
    analyze_image_once!
    md = image.metadata
    md["width"] == 1920 && md["height"] == 1080
  rescue ActiveStorage::FileNotFoundError
    false
  end

  # Used by RailsAdmin to label slide objects
  def rails_admin_label
    if title.present?
      title
    elsif image.attached?
      image.filename.base
    else
      "Slide ##{id}"
    end
  end

  # Fallback for any to_s calls
  def to_s
    rails_admin_label
  end

  # Return a slice of the image metadata once analyzed (if available)
  def image_metadata
    analyze_image_once!
    image.metadata.slice("width", "height", "content_type")
  rescue ActiveStorage::FileNotFoundError
    {}
  end

  # Override kiosk_ids= so “invisible” kiosks always stay assigned
  def kiosk_ids=(incoming_ids)
    submitted = Array(incoming_ids).reject(&:blank?).map(&:to_i)
    allowed   = Kiosk.where(kiosk_group_id: Current.user.kiosk_group_ids).pluck(:id)
    hidden    = self.kiosk_ids - allowed
    super((submitted & allowed) | hidden)
  end


  private

  # If the user left title blank, use the image filename (without extension)
  def set_default_title
    return if title.present? || !image.attached?
    self.title = image.filename.base
  end

  # If display_seconds wasn't provided, default to 10
  def set_default_display_seconds
    self.display_seconds = 10 if display_seconds.blank?
  end

  def set_default_start_date
    self.start_date ||= Time.zone.today
  end

  def start_date_before_end_date
    return if start_date.blank? || end_date.blank?
    if end_date < start_date
      errors.add(:end_date, "must be on or after the start date")
    end
  end

  # Kick off analysis (once) so metadata["width"/"height"] is populated
  def analyze_image_once!
    return if image.analyzed?
    image.analyze
  end
end
