class CreateJoinTableUserPermissionsKioskGroups < ActiveRecord::Migration[7.1]
  def change
    create_join_table :user_permissions, :kiosk_groups do |t|
      # t.index [:user_permission_id, :kiosk_group_id]
      # t.index [:kiosk_group_id, :user_permission_id]
    end
  end
end
