# app/models/user.rb
class User < ApplicationRecord
  # add a column :image_url:string via migration
  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_initialize.tap do |u|
      u.name       = auth.info.name
      u.image_url  = auth.info.image   # ← store their Google avatar URL
      u.save!
    end
  end

  # RailsAdmin will call `avatar_url` if you define it:
  def avatar_url
    image_url.presence || GravatarBuilder.new(email).url
  end

  # associations for permissions
  has_many :user_permissions, dependent: :destroy
  has_many :permissions, through: :user_permissions

  # convenience checker
  def can?(perm_name)
    permissions.exists?(name: perm_name.to_s)
  end

end

