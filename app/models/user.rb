# app/models/user.rb
class User < ApplicationRecord
  # ——————————————————————————————————————————
  # find-or-create by omniauth, but only authorized google domain accounts
  def self.from_omniauth(auth)
    email = auth.info.email.to_s.downcase
    return nil unless email.end_with?("@#{GOOGLE_DOMAIN}")

    # first_or_initialize so we update name/avatar on every login
    where(email: email).first_or_initialize.tap do |u|
      u.name      = auth.info.name
      u.image_url = auth.info.image
      # first time through, make them a plain user
      u.admin = false if u.new_record?
      u.save!
    end
  end

  # RailsAdmin will use this (and your avatar_url fallback)
  def avatar_url
    image_url.presence || GravatarBuilder.new(email).url
  end

  def full_name
    name
  end

  # ——————————————————————————————————————————
  # associations for permissions
  has_many :user_permissions, dependent: :destroy
  has_many :kiosk_groups, through: :user_permissions
  has_many :kiosks, through: :user_permissions
  has_many :permissions, through: :user_permissions

  after_create :auto_provision_default_permission

  # admin? comes for free if you have a boolean `admin` column
  # but override can? so admins always have every ability:
  def can?(perm_name)
    return true if admin?
    permissions.exists?(name: perm_name.to_s)
  end

  def accessible_kiosks
    return Kiosk.all if admin? || can?("manage_kioskgroups") || can?("manage_kiosks")

    Kiosk.where(id: accessible_kiosk_ids)
  end

  def accessible_kiosk_ids
    return Kiosk.ids if admin? || can?("manage_kioskgroups") || can?("manage_kiosks")

    direct_ids = user_permissions.joins(:kiosks).pluck("kiosks.id")
    group_ids = kiosk_group_ids
    group_kiosk_ids = group_ids.any? ? Kiosk.where(kiosk_group_id: group_ids).pluck(:id) : []

    (direct_ids + group_kiosk_ids).uniq
  end

  def accessible_kiosk_group_ids
    return KioskGroup.ids if admin? || can?("manage_kioskgroups") || can?("manage_kiosks")

    kiosk_group_ids_from_kiosks = Kiosk.where(id: accessible_kiosk_ids).pluck(:kiosk_group_id)
    (kiosk_group_ids + kiosk_group_ids_from_kiosks).compact.uniq
  end

  def readable_slide_ids
    return Slide.ids if admin?
    return [] unless can?("manage_slides")

    Slide.joins(:kiosks)
      .where(kiosks: { id: accessible_kiosk_ids })
      .distinct
      .pluck(:id)
  end

  def editable_slide_ids
    return Slide.ids if admin?
    return [] unless can?("manage_slides")

    allowed_kiosk_ids = accessible_kiosk_ids
    return [] if allowed_kiosk_ids.empty?

    inaccessible_slide_ids = Slide.joins(:kiosks)
      .where.not(kiosks: { id: allowed_kiosk_ids })
      .select(:id)

    Slide.joins(:kiosks)
      .where(kiosks: { id: allowed_kiosk_ids })
      .where.not(id: inaccessible_slide_ids)
      .distinct
      .pluck(:id)
  end

  private

  def auto_provision_default_permission
    # Look up whatever “starter” role you want new users to have.
    # You might seed your permissions table with a name like 'staff' or 'guest'.
    default = Permission.find_by(name: 'staff') 
    return unless default

    # Create the join record; they start with zero kiosk_groups.
    user_permissions.create(permission: default)
  end
end
