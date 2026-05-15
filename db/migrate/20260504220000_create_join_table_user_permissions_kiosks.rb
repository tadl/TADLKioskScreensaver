class CreateJoinTableUserPermissionsKiosks < ActiveRecord::Migration[7.1]
  def change
    create_join_table :user_permissions, :kiosks do |t|
      t.index [:user_permission_id, :kiosk_id], unique: true
      t.index [:kiosk_id, :user_permission_id]
    end
  end
end
