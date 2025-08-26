# app/models/slide.rb
# frozen_string_literal: true

class Slide < ApplicationRecord
  has_and_belongs_to_many :kiosks
  has_one_attached :image

  # Defaults
  before_validation :set_default_title
  before_validation :set_default_display_seconds
  before_validation :set_default_start_date, on: :create

  # Core validations
  validates :title, presence: true
  validates :display_seconds, numericality: { only_integer: true, greater_than: 0 }
  validate  :start_date_before_end_date
  validate  :image_must_be_exactly_1080p, if: -> { image.attached? || pending_attachable.present? }

  scope :fallbacks, -> { where(fallback: true) }

  # ——————————————————————————————————————————
  # Helpers

  def valid_dimensions?
    w, h = read_dimensions_now
    w == 1920 && h == 1080
  rescue
    false
  end

  def rails_admin_label
    if title.present?
      title
    elsif image.attached?
      image.filename.base
    else
      "Slide ##{id}"
    end
  end
  def to_s = rails_admin_label

  def image_metadata
    ensure_blob_dimensions_cached
    image.metadata.slice("width", "height", "content_type")
  rescue
    {}
  end

  def kiosk_ids=(incoming_ids)
    submitted = Array(incoming_ids).reject(&:blank?).map(&:to_i)

    u = Current.user
    allowed =
      if u&.admin? || u&.can?('manage_kioskgroups') || u&.can?('manage_kiosks')
        Kiosk.pluck(:id)
      elsif u
        Kiosk.where(kiosk_group_id: u.kiosk_group_ids).pluck(:id)
      else
        Kiosk.pluck(:id)
      end

    hidden = self.kiosk_ids - allowed
    super((submitted & allowed) | hidden)
  end

  private

  def image_must_be_exactly_1080p
    w, h = read_dimensions_now

    if w.nil? || h.nil?
      errors.add(:image, "couldn’t be analyzed. Please try again.")
      detach_pending_upload!
      return
    end

    unless w == 1920 && h == 1080
      errors.add(:image, "must be exactly 1920×1080 (got #{w}×#{h})")
      detach_pending_upload!
    end
  rescue => e
    Rails.logger.warn("[ImageDimensions] #{e.class}: #{e.message}")
    errors.add(:image, "couldn’t be analyzed. Please try again.")
    detach_pending_upload!
  end

  def read_dimensions_now
    if (att = pending_attachable)
      if att.respond_to?(:tempfile)
        path = att.tempfile.path
        if defined?(FastImage)
          if (size = FastImage.size(path))
            return [size[0], size[1]]
          end
        end
        if defined?(MiniMagick)
          img = MiniMagick::Image.open(path)
          return [img.width, img.height]
        end
      elsif att.is_a?(ActiveStorage::Blob)
        return read_dims_from_blob(att)
      end
    end

    return read_dims_from_blob(image.blob) if image.attached? && image.blob.present?

    [nil, nil]
  end

  def read_dims_from_blob(blob)
    return [blob.metadata["width"], blob.metadata["height"]] if blob.metadata["width"] && blob.metadata["height"]

    dims = nil
    blob.open(tmpdir: Dir.tmpdir) do |file|
      if defined?(FastImage)
        if (size = FastImage.size(file.path))
          dims = [size[0], size[1]]
        end
      end
      if dims.nil? && defined?(MiniMagick)
        img  = MiniMagick::Image.open(file.path)
        dims = [img.width, img.height]
      end
    end

    if dims && dims.compact.size == 2
      w, h = dims
      blob.update!(metadata: blob.metadata.merge("width" => w, "height" => h))
    end

    dims || [nil, nil]
  end

  def pending_attachable
    change = attachment_changes["image"]
    change&.attachable
  rescue
    nil
  end

  def detach_pending_upload!
    if attachment_changes["image"].present?
      image.detach
    end
  rescue => e
    Rails.logger.debug("[ImageDimensions] detach skipped: #{e.class}: #{e.message}")
  end

  def ensure_blob_dimensions_cached
    return unless image.attached? && image.blob.present?
    return if image.blob.metadata["width"].present? && image.blob.metadata["height"].present?

    w, h = read_dims_from_blob(image.blob)
    if w && h && (!image.blob.metadata["width"] || !image.blob.metadata["height"])
      image.blob.update!(metadata: image.blob.metadata.merge("width" => w, "height" => h))
    end
  rescue => e
    Rails.logger.debug("[ImageDimensions] cache fail: #{e.class}: #{e.message}")
  end

  # Defaults
  def set_default_title
    return if title.present? || !image.attached?
    self.title = image.filename.base
  end

  def set_default_display_seconds
    self.display_seconds = 10 if display_seconds.blank?
  end

  def set_default_start_date
    self.start_date ||= Time.zone.today
  end

  def start_date_before_end_date
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
  end
end
