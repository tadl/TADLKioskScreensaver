# app/models/user_permission.rb
class UserPermission < ApplicationRecord
  belongs_to :user
  belongs_to :permission

  has_and_belongs_to_many :kiosk_groups
  has_and_belongs_to_many :kiosks

  validates :permission_id, uniqueness: { scope: :user_id }
  validate :assignment_allowed_for_current_user

  after_save :sync_admin_flag_on_user
  after_destroy :sync_admin_flag_on_user
  before_destroy :destruction_allowed_for_current_user

  def rails_admin_label
    user.email.split('@').first
  end

  private

  def assignment_allowed_for_current_user
    actor = Current.user
    return if actor.nil? || actor.admin?

    errors.add(:base, "You cannot change your own permissions") if user_id == actor.id
    errors.add(:permission, "cannot be assigned by a non-admin") if permission&.name == "admin"
    errors.add(:user, "cannot be an admin") if user&.admin?
  end

  def destruction_allowed_for_current_user
    actor = Current.user
    return if actor.nil? || actor.admin?
    return unless user_id == actor.id || user&.admin? || permission&.name == "admin"

    errors.add(:base, "You cannot remove this permission")
    throw :abort
  end

  def sync_admin_flag_on_user
    is_admin = user.permissions.where(name: 'admin').exists?
    user.update_column(:admin, is_admin)
  end
end
