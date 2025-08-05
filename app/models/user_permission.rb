# app/models/user_permission.rb
class UserPermission < ApplicationRecord
  belongs_to :user
  belongs_to :permission

  has_and_belongs_to_many :kiosk_groups

  validates :permission_id, uniqueness: { scope: :user_id }

  after_save :sync_admin_flag_on_user
  after_destroy :sync_admin_flag_on_user

  def rails_admin_label
    user.email.split('@').first
  end

  private

  def sync_admin_flag_on_user
    is_admin = user.permissions.where(name: 'admin').exists?
    user.update_column(:admin, is_admin)
  end
end
