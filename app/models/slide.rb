# frozen_string_literal: true

class Slide < ApplicationRecord
  has_and_belongs_to_many :kiosks
  has_one_attached :image

  # Auto-set title and duration defaults before validation
  before_validation :set_default_title
  before_validation :set_default_display_seconds

  # Core validations
  validates :title, presence: true
  validates :display_seconds,
            numericality: { only_integer: true, greater_than: 0 }
  validate  :start_date_before_end_date

  # New: validate right on upload that the image is 1920×1080
  validate  :validate_image_dimensions, if: -> { image.attached? }

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

  # Ensure (when possible) the upload is exactly 1920×1080px
  def validate_image_dimensions
    begin
      analyze_image_once!
    rescue ActiveStorage::FileNotFoundError
      # image hasn't yet hit disk; we'll skip for now and re-validate on next save
      return
    end

    w =        image.metadata["width"]
    h =        image.metadata["height"]

    unless w == 1920 && h == 1080
      errors.add(
        :image,
        "must be exactly 1920×1080px (we got #{w || 'unknown'}×#{h || 'unknown'})"
      )
    end
  end
end
