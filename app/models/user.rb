# app/models/user.rb
class User < ApplicationRecord
  # ——————————————————————————————————————————
  # find-or-create by omniauth, but only tadl.org accounts
  def self.from_omniauth(auth)
    email = auth.info.email.to_s.downcase
    return nil unless email.end_with?('@tadl.org')

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

  # ——————————————————————————————————————————
  # associations for permissions
  has_many :user_permissions, dependent: :destroy
  has_many :kiosk_groups, through: :user_permissions
  has_many :permissions, through: :user_permissions

  # admin? comes for free if you have a boolean `admin` column
  # but override can? so admins always have every ability:
  def can?(perm_name)
    return true if admin?
    permissions.exists?(name: perm_name.to_s)
  end
end

