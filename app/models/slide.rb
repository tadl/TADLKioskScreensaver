# frozen_string_literal: true

require "mini_magick"

class Slide < ApplicationRecord
  has_and_belongs_to_many :kiosks
  has_one_attached :image

  # Auto-set title and duration defaults before validation
  before_validation :set_default_title
  before_validation :set_default_display_seconds

  validates :title, presence: true
  validates :display_seconds,
            numericality: { only_integer: true, greater_than: 0 }

  validate :start_date_before_end_date

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
end
