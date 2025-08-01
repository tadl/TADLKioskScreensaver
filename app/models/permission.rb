# app/models/permission.rb
class Permission < ApplicationRecord
  has_many :user_permissions, dependent: :destroy
  has_many :users, through: :user_permissions

  validates :name, presence: true, uniqueness: true
end
