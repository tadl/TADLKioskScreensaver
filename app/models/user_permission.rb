# app/models/user_permission.rb
class UserPermission < ApplicationRecord
  belongs_to :user
  belongs_to :permission

  validates :permission_id, uniqueness: { scope: :user_id }

  def rails_admin_label
    user.name
  end
end
