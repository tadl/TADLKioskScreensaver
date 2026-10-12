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
    admin_permission_id = Permission.find_by(name: "admin")&.id
    return unless admin_permission_id

    # Ordinary roles must not revoke an admin flag set by the bootstrap command.
    affected_user_ids = []
    affected_user_ids << user_id if permission_id == admin_permission_id
    if !destroyed? && !previously_new_record? && permission_id_before_last_save == admin_permission_id
      affected_user_ids << user_id_before_last_save
    end

    User.where(id: affected_user_ids.compact.uniq).find_each do |affected_user|
      is_admin = affected_user.permissions.where(id: admin_permission_id).exists?
      affected_user.update_column(:admin, is_admin)
    end
  end
end
