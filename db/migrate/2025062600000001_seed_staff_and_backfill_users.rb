class SeedStaffAndBackfillUsers < ActiveRecord::Migration[7.0]
  def up
    # 1) Create the staff permission
    staff = Permission.find_or_create_by!(name: 'staff')

    # 2) For every user without ANY permission record, give them "staff"
    User.find_each do |user|
      next if user.user_permissions.exists?
      UserPermission.create!(user: user, permission: staff)
    end
  end

  def down
    # Remove only the UserPermission rows you just created:
    staff = Permission.find_by(name: 'staff')
    return unless staff

    # Delete all user_permissions pointing at staff
    UserPermission.where(permission: staff).delete_all

    # And remove the permission itself
    staff.destroy
  end
end
