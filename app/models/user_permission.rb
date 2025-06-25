# app/models/user_permission.rb
class UserPermission < ApplicationRecord
  belongs_to :user
  belongs_to :permission

  has_and_belongs_to_many :kiosk_groups

  validates :permission_id, uniqueness: { scope: :user_id }

  def rails_admin_label
    user.name
  end
end
