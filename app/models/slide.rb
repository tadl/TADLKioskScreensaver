# frozen_string_literal: true

require "mini_magick"

class Slide < ApplicationRecord
  has_and_belongs_to_many :kiosks
  has_one_attached :image

  # Auto-set title from filename and default seconds if blank
  before_validation :apply_defaults

  validates :title, presence: true
  validates :display_seconds,
            presence: true,
            numericality: { only_integer: true, greater_than: 0 }

  validate :start_date_before_end_date
  validate :image_dimensions

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

  private

  def apply_defaults
    # — set title from filename if blank
    if image.attached? && title.blank?
      self.title = image.filename.base
    end

    # — set default display_seconds to 10 if blank or nil
    self.display_seconds = 10 if display_seconds.blank?
  end

  def start_date_before_end_date
    return if start_date.blank? || end_date.blank?
    if end_date < start_date
      errors.add(:end_date, "must be on or after the start date")
    end
  end

  def image_dimensions
    return unless image.attached? && image.content_type.start_with?("image/")

    downloaded = image.download
    tmp = Tempfile.new(
      ["upload", File.extname(image.filename.to_s)],
      binmode: true
    )
    tmp.write(downloaded)
    tmp.rewind

    img = MiniMagick::Image.open(tmp.path)
    w, h = img.width, img.height
    tmp.close!

    if w < 1920 || h < 1080
      errors.add(
        :image,
        "must be at least 1920×1080 (you uploaded #{w}×#{h})"
      )
    end

    target_ratio = 16.0 / 9.0
    ratio        = w.to_f / h
    tolerance    = 0.02
    unless (ratio - target_ratio).abs <= tolerance
      errors.add(
        :image,
        "must be 16:9 aspect ratio (you uploaded #{w}×#{h})"
      )
    end

  rescue => e
    errors.add(:image, "could not be processed for dimensions")
  end
end
